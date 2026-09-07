# Burn-rate math for the super-admin dashboard. Not a real table, just a
# wrapper around an Account so this reporting logic doesn't live on the model.
class AccountBurnPresenter
  delegate :account_id, :company_name, :plan, :status, :monthly_credit_allowance,
           :credits_used_this_cycle, :credits_remaining, :avg_daily_burn, :past_due?,
           to: :account

  attr_reader :account

  def initialize(account)
    @account = account
  end

  def days_until_dry
    return Float::INFINITY if avg_daily_burn.to_i <= 0

    (credits_remaining.to_f / avg_daily_burn).round(1)
  end

  def percent_used
    return 0 if monthly_credit_allowance.to_i.zero?

    ((credits_used_this_cycle.to_f / monthly_credit_allowance) * 100).round
  end

  def at_risk?
    past_due? || credits_remaining <= 0 || days_until_dry < 1
  end
end
