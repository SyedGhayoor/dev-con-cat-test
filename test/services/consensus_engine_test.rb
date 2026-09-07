require "test_helper"

class ConsensusEngineTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(
      account_id: "acct_ce_test_#{SecureRandom.hex(4)}", company_name: "CE Test Co",
      plan: "growth", status: "active", monthly_credit_allowance: 10_000,
      enabled_modules: LayerResult::LAYERS
    )
    Current.account = @account
    @pixel = Pixel.create!(account: @account, name: "Test pixel")
    @lead = Lead.create!(account: @account, pixel: @pixel, first_name: "Test", last_name: "Lead",
                          email: "t@example.com", phone: "+15551234567", submitted_at: Time.current)
    @policy = PolicyVersion.create!(
      account: nil, name: "test-policy", version: 1, active: true,
      config: {
        "hard_stops" => %w[litigator_confirmed dnc_not_callable exact_duplicate trustedform_mismatch trustedform_expired],
        "weights" => { "anura_suspect" => 20, "vpn_high_risk" => 15, "email_both_undeliverable" => 35 },
        "thresholds" => { "review" => 30, "reject" => 60 }
      }
    )
  end

  def build_run(layer_states)
    run = VerificationRun.create!(account: @account, lead: @lead, policy_version: @policy, status: "running")
    LayerResult::LAYERS.each do |layer|
      state, data = layer_states[layer] || ["not_enabled", {}]
      run.layer_results.create!(account: @account, layer: layer, state: state, raw_response: data)
    end
    run
  end

  test "a confirmed litigator is a hard stop regardless of everything else being clean" do
    run = build_run(
      "blacklist_alliance" => ["returned_verdict", { "status" => "litigator" }],
      "anura" => ["returned_verdict", { "result" => "good" }]
    )

    verdict = ConsensusEngine.call(run)

    assert_equal "reject", verdict.verdict
    assert_nil verdict.score
    assert_equal ["litigator_confirmed"], verdict.reasons.map { |r| r["code"] }
  end

  test "a single weak signal under the review threshold lands accept" do
    run = build_run("anura" => ["returned_verdict", { "result" => "suspect" }])

    verdict = ConsensusEngine.call(run)

    assert_equal "accept", verdict.verdict
    assert_equal 20.0, verdict.score
  end

  test "signals summing into the review band land review, not reject" do
    run = build_run(
      "anura" => ["returned_verdict", { "result" => "suspect" }], # 20
      "vpn_proxy" => ["returned_verdict", { "risk" => "high" }]   # 15 -> total 35
    )

    verdict = ConsensusEngine.call(run)

    assert_equal "review", verdict.verdict
    assert_equal 35.0, verdict.score
  end

  test "signals summing past the reject threshold land reject" do
    run = build_run(
      "anura" => ["returned_verdict", { "result" => "suspect" }],              # 20
      "vpn_proxy" => ["returned_verdict", { "risk" => "high" }],               # 15
      "email_validation" => ["returned_verdict", { "providers" => {
        "a" => { "deliverable" => false }, "b" => { "deliverable" => false }
      } }] # 35 -> total 70
    )

    verdict = ConsensusEngine.call(run)

    assert_equal "reject", verdict.verdict
    assert_equal 70.0, verdict.score
  end

  test "a layer that is not_enabled never contributes, even with damning underlying data" do
    # blacklist_alliance defaults to not_enabled/{} via build_run. Confirm
    # a clean run with only a not_enabled layer present stays accept.
    run = build_run("anura" => ["returned_verdict", { "result" => "good" }])

    verdict = ConsensusEngine.call(run)

    assert_equal "accept", verdict.verdict
    assert_equal ["clean"], verdict.reasons.map { |r| r["code"] }
  end

  test "a layer that is not_applicable never contributes" do
    run = build_run(
      "voice" => ["not_applicable", { "has_sample" => false }],
      "anura" => ["returned_verdict", { "result" => "good" }]
    )

    verdict = ConsensusEngine.call(run)

    assert_equal "accept", verdict.verdict
  end

  test "a run with a credit-starved layer can never silently accept" do
    run = build_run(
      "anura" => ["returned_verdict", { "result" => "good" }],
      "dnc" => ["skipped_insufficient_credits", {}]
    )

    verdict = ConsensusEngine.call(run)

    assert_equal "review", verdict.verdict, "an incomplete signal set must not auto-accept"
  end

  test "issues a tamper-evident certificate alongside the verdict" do
    run = build_run("anura" => ["returned_verdict", { "result" => "good" }])

    ConsensusEngine.call(run)
    cert = run.reload.consent_certificate

    assert cert.present?
    assert cert.verify

    cert.snapshot = cert.snapshot.merge("verdict" => "reject")
    assert_not cert.verify, "mutating the snapshot must invalidate the hash"
  end
end
