# Turns a completed run's LayerResults into ACCEPT/REVIEW/REJECT plus a
# reason trail. Two tiers:
#
#   1. Hard stops: a short, policy-configurable list that short-circuits
#      straight to REJECT (confirmed litigator, DNC, exact duplicate,
#      TrustedForm mismatch/expired). Nothing else matters if one of these
#      fires.
#   2. Weighted signals: everything else accumulates a score against
#      policy weights, and thresholds map the score to a verdict.
#
# Weights/thresholds/hard-stop membership live in PolicyVersion#config
# (data, not code) so a buyer can retune this without a deploy.
#
# A layer only counts if it actually ran (state == returned_verdict).
# not_enabled/not_applicable/skipped layers are silently excluded. Exception:
# if any layer was skipped for lack of credits, the verdict is clamped to at
# least REVIEW so an incomplete run can never auto-accept.
class ConsensusEngine
  def self.call(run) = new(run).call

  HARD_STOPS = {
    "litigator_confirmed" => {
      layer: "blacklist_alliance", check: ->(d) { d["status"] == "litigator" },
      text: "Confirmed serial TCPA litigator match."
    },
    "dnc_not_callable" => {
      layer: "dnc", check: ->(d) { %w[dnc_listed internal_dnc].include?(d["dnc_status"]) },
      text: "Number is on a Do-Not-Call list."
    },
    "exact_duplicate" => {
      layer: "duplicate_detection", check: ->(d) { d["match_type"] == "exact" },
      text: "Exact duplicate of an existing CRM record (same phone and email)."
    },
    "trustedform_mismatch" => {
      layer: "trustedform", check: ->(d) { d["status"] == "mismatch" },
      text: "Retained consent certificate does not match this lead."
    },
    "trustedform_expired" => {
      layer: "trustedform", check: ->(d) { d["status"] == "expired" },
      text: "Retained consent certificate has expired."
    }
  }.freeze

  SIGNALS = {
    "vpn_or_proxy_detected" => {
      layer: "vpn_proxy", check: ->(d) { d["is_vpn"] || d["is_proxy"] || d["is_tor"] || d["is_datacenter"] },
      text: "VPN, proxy, or Tor exit node detected."
    },
    "site_visit_ip_mismatch" => {
      layer: "vpn_proxy", check: ->(d) { d["site_visit_ip_matches_submit_ip"] == false },
      text: "Site-visit IP does not match the submit IP."
    },
    "vpn_high_risk" => {
      layer: "vpn_proxy", check: ->(d) { d["risk"] == "high" }, text: "VPN/proxy layer flagged high risk."
    },
    "vpn_medium_risk" => {
      layer: "vpn_proxy", check: ->(d) { d["risk"] == "medium" }, text: "VPN/proxy layer flagged medium risk."
    },
    "anura_suspect" => {
      layer: "anura", check: ->(d) { d["result"] == "suspect" }, text: "Anura flagged this traffic as suspect."
    },
    "anura_bad" => {
      layer: "anura", check: ->(d) { d["result"] == "bad" }, text: "Anura flagged this traffic as bad (bot/fraud farm)."
    },
    "litigator_suspected" => {
      layer: "blacklist_alliance", check: ->(d) { d["status"] == "suspected" },
      text: "Suspected (not confirmed) TCPA litigator match."
    },
    "trustedform_not_found" => {
      layer: "trustedform", check: ->(d) { d["status"] == "not_found" },
      text: "No retained consent certificate was found."
    },
    "phone_providers_disagree" => {
      layer: "phone_validation", check: ->(d) { provider_values(d, "valid").uniq.size > 1 },
      text: "Phone validation providers disagree on validity."
    },
    "phone_voip_flagged" => {
      layer: "phone_validation", check: ->(d) { provider_values(d, "line_type").include?("voip") },
      text: "At least one phone provider flagged a VoIP line."
    },
    "email_both_undeliverable" => {
      layer: "email_validation", check: ->(d) { provider_values(d, "deliverable").all? { |v| v == false } },
      text: "Both email providers agree the address is undeliverable."
    },
    "email_providers_disagree" => {
      layer: "email_validation", check: ->(d) { provider_values(d, "deliverable").uniq.size > 1 },
      text: "Email providers disagree on deliverability."
    },
    "email_disposable" => {
      layer: "email_validation", check: ->(d) { provider_values(d, "disposable").any? },
      text: "Email flagged as a disposable address."
    },
    "email_high_fraud_score" => {
      layer: "email_validation",
      check: ->(d) { provider_values(d, "disposable").none? && provider_values(d, "fraud_score").any? { |v| (v || 0) > 50 } },
      text: "Email fraud score is elevated."
    },
    "enrichment_sources_disagree" => {
      layer: "enrichment", check: ->(d) { d.dig("audiencelabs", "match_to_lead") != d.dig("bytemine", "match_to_lead") },
      text: "Enrichment sources disagree on identity match."
    },
    "enrichment_neither_matched" => {
      layer: "enrichment", check: ->(d) { !d.dig("audiencelabs", "matched") && !d.dig("bytemine", "matched") },
      text: "No enrichment source could match this identity."
    },
    "soft_duplicate" => {
      layer: "duplicate_detection", check: ->(d) { %w[soft_phone soft_email].include?(d["match_type"]) },
      text: "Possible duplicate of an existing CRM record (partial match)."
    },
    "dnc_callback_window_closed" => {
      layer: "dnc", check: ->(d) { d["dnc_status"] == "callable" && d["callback_window_open"] == false },
      text: "Callback window is currently closed."
    },
    "voice_reused_actor" => {
      layer: "voice", check: ->(d) { d["verdict"] == "human_reused_actor" },
      text: "Voiceprint reused across multiple leads (voice-actor fraud)."
    },
    "voice_synthetic" => {
      layer: "voice", check: ->(d) { d["verdict"] == "synthetic" },
      text: "Voice sample flagged as synthetic/AI-generated."
    }
  }.freeze

  def self.provider_values(data, key)
    (data["providers"] || {}).values.map { |p| p[key] }
  end

  def initialize(run)
    @run = run
    @policy = run.policy_version
    @by_layer = run.layer_results.index_by(&:layer)
  end

  def call
    hard_stop = find_hard_stop
    verdict, reasons, score =
      if hard_stop
        ["reject", [hard_stop], nil]
      else
        compute_weighted
      end

    verdict = clamp_for_incomplete_run(verdict)

    consensus = ConsensusVerdict.create!(
      verification_run: @run, account: @run.account, policy_version: @policy,
      verdict: verdict, score: score, reasons: reasons
    )

    ConsentCertificates::Issue.call(@run, consensus)

    ActivityEvent.record!(
      account: @run.account, lead: @run.lead, verification_run: @run, event_type: "verdict_issued",
      payload: { "verdict" => verdict, "score" => score, "reasons" => reasons.map { |r| r["human_text"] } }
    )

    consensus
  end

  private

  def find_hard_stop
    configured = @policy.hard_stops
    HARD_STOPS.each do |code, spec|
      next unless configured.include?(code)

      lr = @by_layer[spec[:layer]]
      next unless lr&.ran?
      next unless spec[:check].call(lr.raw_response)

      return { "code" => code, "layer" => spec[:layer], "weight" => nil, "human_text" => spec[:text] }
    end
    nil
  end

  def compute_weighted
    weights = @policy.weights
    fired = []
    score = 0.0

    SIGNALS.each do |code, spec|
      next unless weights.key?(code)

      lr = @by_layer[spec[:layer]]
      next unless lr&.ran?
      next unless spec[:check].call(lr.raw_response)

      weight = weights[code].to_f
      score += weight
      fired << { "code" => code, "layer" => spec[:layer], "weight" => weight, "human_text" => spec[:text] }
    end

    thresholds = @policy.thresholds
    verdict =
      if score >= (thresholds["reject"] || 60)
        "reject"
      elsif score >= (thresholds["review"] || 30)
        "review"
      else
        "accept"
      end

    reasons = fired.presence || [
      { "code" => "clean", "layer" => nil, "weight" => 0, "human_text" => "All enabled layers passed with no signals raised." }
    ]
    [verdict, reasons, score]
  end

  def clamp_for_incomplete_run(verdict)
    return verdict unless @run.layer_results.exists?(state: "skipped_insufficient_credits")

    verdict == "accept" ? "review" : verdict
  end
end
