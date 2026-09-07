module Admin
  class AccountsController < BaseController
    def index
      @accounts = Account.order(:company_name).map { |a| AccountBurnPresenter.new(a) }
    end

    def show
      @account = Account.find(params[:id])
      @presenter = AccountBurnPresenter.new(@account)
      @users = @account.users.order(:role)
      @pixels = @account.pixels.order(:name)
      @recent_leads = @account.leads.order(created_at: :desc).limit(10)
      @recent_ledger = @account.credit_ledger_entries.order(created_at: :desc).limit(20)
    end
  end
end
