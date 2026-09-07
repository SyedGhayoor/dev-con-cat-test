require "test_helper"

class AccountTest < ActiveSupport::TestCase
  # The concurrent-debit test below spawns real threads, each needing its own
  # DB connection to see committed rows. Rails' default transactional test
  # wrapper would keep this test's data uncommitted and invisible to them.
  self.use_transactional_tests = false

  setup do
    @account = Account.create!(
      account_id: "acct_credit_#{SecureRandom.hex(4)}", company_name: "Credit Test Co",
      plan: "starter", status: "active", monthly_credit_allowance: 10, enabled_modules: []
    )
    # Not used by debit_credits! itself (Account/CreditLedgerEntry aren't
    # tenant-scoped), but destroying an account in teardown cascades through
    # several associations that are.
    Current.account = @account
  end

  teardown do
    @account.destroy
  end

  test "debit_credits! records a ledger entry and updates the running balance atomically" do
    result = @account.debit_credits!(3, reason: "layer_attempted:anura")

    assert_equal :debited, result
    assert_equal 7, @account.reload.credits_remaining
    entry = @account.credit_ledger_entries.last
    assert_equal(-3, entry.delta)
    assert_equal 7, entry.balance_after
  end

  test "debit_credits! refuses to take the balance negative" do
    @account.update!(credits_used_this_cycle: 9) # 1 credit remaining

    result = @account.debit_credits!(3, reason: "layer_attempted:enrichment")

    assert_equal :insufficient, result
    assert_equal 1, @account.reload.credits_remaining, "balance must be untouched on a rejected debit"
  end

  test "concurrent debits never overdraw the balance" do
    @account.update!(credits_used_this_cycle: 8) # 2 credits remaining

    # Five threads each try to spend 1 credit; only 2 can succeed. This is
    # the exact race a fan-out of per-layer jobs hits in production. See
    # RunLayerJob, and the with_lock in Account#debit_credits! this guards.
    results = 5.times.map do
      Thread.new { @account.debit_credits!(1, reason: "layer_attempted:dnc") }
    end.map(&:value)

    assert_equal 2, results.count(:debited)
    assert_equal 3, results.count(:insufficient)
    assert_equal 0, @account.reload.credits_remaining
  end
end
