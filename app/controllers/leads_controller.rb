class LeadsController < ApplicationController
  def index
    @leads = policy_scope(Lead).includes(verification_runs: :consensus_verdict).order(created_at: :desc)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @leads = @leads.where(
        "first_name ILIKE :q OR last_name ILIKE :q OR email ILIKE :q OR phone ILIKE :q OR lead_id ILIKE :q",
        q: q
      )
    end

    if params[:verdict].present?
      @leads = @leads.joins(verification_runs: :consensus_verdict)
                      .where(consensus_verdicts: { verdict: params[:verdict] })
    end
  end

  def show
    @lead = authorize current_account.leads.find(params[:id])
    @run = @lead.verification_runs.order(created_at: :desc).first
    @activity = @lead.activity_events.order(occurred_at: :desc)
  end
end
