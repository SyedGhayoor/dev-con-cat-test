module ConsentCertificates
  # Issued right after the verdict. The snapshot is a frozen copy of every
  # layer's raw response plus the verdict/reasons, and content_hash lets
  # anyone re-verify it hasn't been altered without trusting the DB row.
  class Issue
    def self.call(run, consensus) = new(run, consensus).call

    def initialize(run, consensus)
      @run = run
      @consensus = consensus
    end

    def call
      snapshot = build_snapshot
      ConsentCertificate.create!(
        lead: @run.lead,
        verification_run: @run,
        account: @run.account,
        trusted_form_cert_url: trustedform_reference,
        issued_at: Time.current,
        snapshot: snapshot,
        content_hash: ConsentCertificate.hash_for(snapshot)
      )
    end

    private

    # Only cite the TrustedForm cert if that layer actually verified it.
    # A mismatched/expired/not_found cert shouldn't read as supporting evidence.
    def trustedform_reference
      tf = @run.layer_results.find_by(layer: "trustedform")
      return nil unless tf&.ran? && tf.raw_response["status"] == "verified"

      @run.lead.trusted_form_cert_url
    end

    def build_snapshot
      {
        "lead_id" => @run.lead.lead_id,
        "account_id" => @run.account.account_id,
        "verification_run_id" => @run.id,
        "policy_version_id" => @consensus.policy_version_id,
        "verdict" => @consensus.verdict,
        "score" => @consensus.score,
        "reasons" => @consensus.reasons,
        "layers" => @run.layer_results.order(:layer).map { |lr|
          {
            "layer" => lr.layer, "state" => lr.state,
            "raw_response" => lr.raw_response, "credits_charged" => lr.credits_charged
          }
        },
        "issued_at" => Time.current.iso8601
      }
    end
  end
end
