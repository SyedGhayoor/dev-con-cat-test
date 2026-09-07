# One job per detection layer, fanned out by VerificationRuns::Start. Each
# job independently resolves its own three(+one)-way state: not_enabled,
# not_applicable, returned_verdict, or skipped_insufficient_credits. So a
# slow or "failing" layer never blocks the others. Writing an ActivityEvent
# row is what "publishes" the result: Api::Pixel::ActivityController tails
# this table with a cursor, so the live panel has no dependency on this job
# and that controller being in the same process at the same time.
class RunLayerJob < ApplicationJob
  queue_as :default

  def perform(verification_run_id, layer)
    # Jobs have no logged-in user, so there's no tenant context yet. This
    # is a deliberate unscoped lookup by a job-internal ID (never user
    # input), same pattern as the pixel/activity controllers.
    run = VerificationRun.unscoped.find(verification_run_id)
    Current.account = run.account

    return if run.layer_results.exists?(layer: layer) # idempotency safety net

    account = run.account
    lead = run.lead

    outcome = resolve(run, account, lead, layer)

    run.layer_results.create!(
      account: account, layer: layer, state: outcome[:state],
      raw_response: outcome[:data], credits_charged: outcome[:cost],
      evaluated_at: Time.current
    )

    ActivityEvent.record!(account: account, lead: lead, verification_run: run, event_type: "layer_completed",
                           payload: { "layer" => layer, "state" => outcome[:state], "data" => outcome[:data] })

    finalize_if_complete(run)
  end

  private

  def resolve(run, account, lead, layer)
    return { state: "not_enabled", data: {}, cost: 0 } unless account.module_enabled?(layer)

    outcome = Layers.for(layer).call(lead)
    return { state: "not_applicable", data: outcome[:data], cost: 0 } unless outcome[:applicable]

    cost = ModuleCost.for(layer)
    result = account.debit_credits!(cost, reason: "layer_attempted:#{layer}", verification_run: run, layer: layer)
    return { state: "skipped_insufficient_credits", data: {}, cost: 0 } if result == :insufficient

    { state: "returned_verdict", data: outcome[:data], cost: cost }
  end

  def finalize_if_complete(run)
    return unless run.reload.complete?
    return if run.consensus_verdict.present?

    # ConsensusVerdict has a unique index on verification_run_id, so if two
    # layer jobs finish near-simultaneously and both see complete?, only one
    # wins the insert; the other hits RecordNotUnique and backs off. Status
    # only flips to "completed" once the verdict genuinely exists, so nothing
    # observing `status` can see "completed" before a verdict is queryable.
    ConsensusEngine.call(run)
    run.update!(status: "completed", completed_at: Time.current)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
