require "test_helper"

# Unit-level proof that TenantScoped's default_scope is a real wall, not
# just a convention. See test/integration/tenant_isolation_test.rb for the
# HTTP-level version of the same guarantee.
class TenantScopingTest < ActiveSupport::TestCase
  test "a bare query on a tenant-owned model raises with no tenant context set" do
    assert_raises(Current::NoTenantContextError) { Lead.first }
    assert_raises(Current::NoTenantContextError) { Pixel.count }
    assert_raises(Current::NoTenantContextError) { VerificationRun.count }
  end

  test "the same query works once a tenant context is set" do
    account = Account.create!(
      account_id: "acct_scope_test_#{SecureRandom.hex(4)}", company_name: "Scope Test Co",
      plan: "growth", status: "active", monthly_credit_allowance: 100, enabled_modules: []
    )
    Current.account = account

    assert_nothing_raised { Lead.count }
  end

  test "super_admin_override bypasses the tenant filter instead of raising" do
    Current.super_admin_override = true

    assert_nothing_raised { Lead.count }
  end
end
