module VerificationRuns
  # Entry point called by the ingestion controller right after a lead is
  # created. Also what db/seeds.rb calls for the 12 example leads, so
  # there's no special seeding-only path. Fans out one background job per layer.
  class Start
    def self.call(lead) = new(lead).call

    def initialize(lead)
      @lead = lead
    end

    def call
      policy = PolicyVersion.default_for(@lead.account)
      run = VerificationRun.create!(
        account: @lead.account, lead: @lead, policy_version: policy,
        status: "running", started_at: Time.current
      )

      ActivityEvent.record!(account: @lead.account, lead: @lead, verification_run: run,
                             event_type: "verification_started")

      LayerResult::LAYERS.each { |layer| RunLayerJob.perform_later(run.id, layer) }

      run
    end
  end
end
