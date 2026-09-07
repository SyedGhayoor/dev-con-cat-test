class Account < ApplicationRecord
  PLANS = %w[starter growth enterprise].freeze
  STATUSES = %w[active past_due suspended].freeze

  # destroy order matters here: leads (and everything hanging off them via
  # verification_runs) have to go before capture_sessions/pixels, and
  # policy_versions has to go after verification_runs since it's an FK target.
  has_many :leads, dependent: :destroy
  has_many :consent_certificates, dependent: :destroy
  has_many :verification_runs, dependent: :destroy
  has_many :capture_sessions, dependent: :destroy
  has_many :pixels, dependent: :destroy
  has_many :policy_versions, dependent: :destroy
  has_many :crm_contacts, dependent: :destroy
  has_many :credit_ledger_entries, dependent: :destroy
  has_many :activity_events, dependent: :destroy
  has_many :users, dependent: :destroy

  validates :account_id, presence: true, uniqueness: true
  validates :company_name, presence: true
  validates :plan, inclusion: { in: PLANS }
  validates :status, inclusion: { in: STATUSES }

  def module_enabled?(layer)
    enabled_modules.include?(layer.to_s)
  end

  def credits_remaining
    monthly_credit_allowance - credits_used_this_cycle
  end

  def past_due? = status == "past_due"

  # Checking "enough credits?" has to happen inside the lock, not before it -
  # several layer jobs debit the same account at once, and a pre-check done
  # outside the lock can pass for more of them than the balance can cover.
  def debit_credits!(amount, reason:, verification_run: nil, layer: nil)
    return :zero if amount.zero?

    with_lock do
      return :insufficient if credits_remaining < amount

      new_used = credits_used_this_cycle + amount
      update!(credits_used_this_cycle: new_used)
      credit_ledger_entries.create!(
        verification_run: verification_run,
        layer: layer,
        delta: -amount,
        reason: reason,
        balance_after: monthly_credit_allowance - new_used
      )
      :debited
    end
  end
end
