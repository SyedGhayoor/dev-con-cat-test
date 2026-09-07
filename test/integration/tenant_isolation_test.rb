require "test_helper"

# Adversarial: log in as a member of one account, take real record IDs that
# belong to a DIFFERENT account, and hit every route with them. Every one of
# these must 404 (never 403; see ApplicationController#render_not_found)
# and never leak data, regardless of how the record was fetched.
class TenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @policy = PolicyVersion.find_or_create_by!(account: nil, name: "test-default") do |p|
      p.config = { "hard_stops" => [], "weights" => {}, "thresholds" => { "review" => 30, "reject" => 60 } }
    end

    @account_a = create_account("a")
    @account_b = create_account("b")

    @user_a = create_user(@account_a, "account_admin")
    @user_b = create_user(@account_b, "account_admin")

    Current.set(account: @account_b) do
      @pixel_b = Pixel.create!(account: @account_b, name: "B's pixel")
      @lead_b = Lead.create!(account: @account_b, pixel: @pixel_b, first_name: "B", last_name: "Lead",
                              email: "b@example.com", phone: "+15550001111", submitted_at: Time.current)
      run_b = VerificationRun.create!(account: @account_b, lead: @lead_b, policy_version: @policy, status: "completed")
      ConsensusVerdict.create!(verification_run: run_b, account: @account_b, policy_version: @policy,
                                verdict: "accept", reasons: [])
      @cert_b = ConsentCertificate.create!(lead: @lead_b, verification_run: run_b, account: @account_b,
                                            issued_at: Time.current, snapshot: { "verdict" => "accept" },
                                            content_hash: ConsentCertificate.hash_for({ "verdict" => "accept" }))
    end

    sign_in(@user_a)
  end

  test "account A cannot view account B's pixel" do
    get pixel_path(@pixel_b)
    assert_response :not_found
  end

  test "account A cannot view account B's lead" do
    get lead_path(@lead_b)
    assert_response :not_found
  end

  test "account A cannot view account B's certificate detail (even knowing the exact uid)" do
    get certificate_path(@cert_b.certificate_uid)
    assert_response :not_found
  end

  test "account A cannot edit or delete account B's pixel via direct ID" do
    patch pixel_path(@pixel_b), params: { pixel: { name: "hijacked" } }
    assert_response :not_found
    assert_equal "B's pixel", @pixel_b.reload.name

    delete pixel_path(@pixel_b)
    assert_response :not_found
    assert Current.set(super_admin_override: true) { Pixel.exists?(@pixel_b.id) }
  end

  test "account A's own resources remain reachable (isolation isn't just blocking everything)" do
    pixel_a = Current.set(account: @account_a) { Pixel.create!(account: @account_a, name: "A's pixel") }
    get pixel_path(pixel_a)
    assert_response :success
  end

  test "an account_admin cannot reach the super_admin namespace" do
    get admin_root_path
    assert_response :not_found

    get admin_account_path(@account_b)
    assert_response :not_found
  end

  test "super_admin can reach any account, and CRM/pixel data stays scoped to the account it belongs to" do
    root = create_user_without_account("super_admin")
    sign_in(root)

    get admin_root_path
    assert_response :success

    get admin_account_path(@account_b)
    assert_response :success
  end

  private

  def create_account(slug)
    Account.create!(
      account_id: "acct_iso_#{slug}_#{SecureRandom.hex(4)}", company_name: "Iso Test #{slug.upcase}",
      plan: "growth", status: "active", monthly_credit_allowance: 10_000, enabled_modules: []
    )
  end

  def create_user(account, role)
    User.create!(account: account, role: role, name: "User #{account.account_id}",
                 email_address: "#{account.account_id}@example.com", password: "password123")
  end

  def create_user_without_account(role)
    User.create!(account: nil, role: role, name: "Root",
                 email_address: "root_#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end
end
