module Admin
  class DashboardController < BaseController
    def show
      @accounts = Account.order(:company_name).map { |a| AccountBurnPresenter.new(a) }
      @at_risk = @accounts.select(&:at_risk?)
    end
  end
end
