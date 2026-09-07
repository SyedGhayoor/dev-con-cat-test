class DashboardController < ApplicationController
  skip_after_action :verify_authorized, :verify_policy_scoped

  def show
    @account = current_account
    @recent_leads = @account.leads.order(created_at: :desc).limit(10)
  end
end
