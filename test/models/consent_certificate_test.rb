require "test_helper"

class ConsentCertificateTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(
      account_id: "acct_cert_test_#{SecureRandom.hex(4)}", company_name: "Cert Test Co",
      plan: "growth", status: "active", monthly_credit_allowance: 10_000, enabled_modules: []
    )
    Current.account = @account
    @pixel = Pixel.create!(account: @account, name: "Cert test pixel")
    @policy = PolicyVersion.create!(account: nil, name: "cert-test-policy-#{SecureRandom.hex(4)}", config: {})
  end

  def build_certificate(suffix)
    lead = Lead.create!(account: @account, pixel: @pixel, first_name: "T", last_name: suffix,
                         email: "t#{suffix}@example.com", phone: "+155500000#{suffix}",
                         submitted_at: Time.current)
    run = VerificationRun.create!(account: @account, lead: lead, policy_version: @policy, status: "completed")
    snapshot = { "verdict" => "accept", "lead_id" => lead.lead_id }
    ConsentCertificate.create!(lead: lead, verification_run: run, account: @account,
                                issued_at: Time.current, snapshot: snapshot,
                                content_hash: ConsentCertificate.hash_for(snapshot))
  end

  test "each certificate chains to the previous one's hash" do
    first = build_certificate("1")
    second = build_certificate("2")

    assert_equal 1, first.sequence_number
    assert_nil first.previous_hash
    assert_equal 2, second.sequence_number
    assert_equal first.content_hash, second.previous_hash
  end

  test "chain_intact? is true across an untouched chain" do
    build_certificate("1")
    build_certificate("2")
    build_certificate("3")

    assert ConsentCertificate.chain_intact?(@account)
  end

  test "chain_intact? detects a broken link" do
    build_certificate("1")

    # The immutability trigger blocks any real UPDATE/DELETE, including
    # Rails' own update_column. So the only way to simulate a corrupted
    # link (e.g. a bad insert bypassing the app, or a future bug in
    # assign_chain_position) is a raw INSERT with a deliberately wrong
    # previous_hash, which insert_all allows since it skips callbacks.
    lead = Lead.create!(account: @account, pixel: @pixel, first_name: "T", last_name: "broken",
                         email: "broken@example.com", phone: "+15550009999", submitted_at: Time.current)
    run = VerificationRun.create!(account: @account, lead: lead, policy_version: @policy, status: "completed")

    ConsentCertificate.insert_all([{
      lead_id: lead.id, verification_run_id: run.id, account_id: @account.id,
      certificate_uid: "cert_test_broken_#{SecureRandom.hex(4)}",
      content_hash: ConsentCertificate.hash_for({ "verdict" => "accept" }),
      previous_hash: "not-the-real-previous-hash", sequence_number: 2,
      issued_at: Time.current, snapshot: { "verdict" => "accept" }.to_json,
      created_at: Time.current, updated_at: Time.current
    }])

    refute ConsentCertificate.chain_intact?(@account)
  end

  test "the database itself refuses to update or delete a certificate" do
    cert = build_certificate("1")

    # Rails wraps each test in a transaction; a raw SQL error would normally
    # poison that whole transaction (Postgres refuses further statements
    # once one has errored). requires_new: true opens a real SAVEPOINT, so
    # the expected error only rolls back to there, not the whole test.
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute("UPDATE consent_certificates SET content_hash = 'tampered' WHERE id = #{cert.id}")
      end
    end
    assert_match(/immutable/, error.message)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute("DELETE FROM consent_certificates WHERE id = #{cert.id}")
      end
    end
    assert_match(/immutable/, error.message)

    assert ConsentCertificate.exists?(cert.id), "the row must still exist after the blocked delete"
  end
end
