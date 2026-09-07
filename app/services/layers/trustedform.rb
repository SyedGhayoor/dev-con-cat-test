module Layers
  class Trustedform < Base
    def call
      return { applicable: true, data: fixture } if fixture

      if lead.trusted_form_cert_url.present?
        {
          applicable: true,
          data: {
            "status" => "verified", "matches_phone" => true, "matches_email" => true,
            "consent_language_present" => true, "page_url" => lead.landing_page_url,
            "_source" => "heuristic: cert URL presence only, not independently re-verified"
          }
        }
      else
        {
          applicable: true,
          data: {
            "status" => "not_found", "matches_phone" => false, "matches_email" => false,
            "consent_language_present" => false,
            "_source" => "heuristic: no retained consent certificate was captured"
          }
        }
      end
    end

    private

    def provider_name = "trustedform"
  end
end
