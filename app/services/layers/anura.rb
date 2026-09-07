module Layers
  class Anura < Base
    TOO_FAST_MS = 1500

    def call
      return { applicable: true, data: fixture } if fixture

      too_fast = lead.form_dwell_ms.present? && lead.form_dwell_ms < TOO_FAST_MS

      {
        applicable: true,
        data: {
          "result" => (too_fast ? "bad" : "good"),
          "rule_ids" => (too_fast ? ["FORM_FILL_TOO_FAST"] : []),
          "invalid_traffic_type" => (too_fast ? "bot" : nil),
          "confidence" => too_fast ? 0.7 : 0.6,
          "_source" => "heuristic: form dwell-time only, no bot-detection vendor available"
        }
      }
    end

    private

    def provider_name = "anura"
  end
end
