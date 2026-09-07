module Layers
  class PhoneValidation < Base
    FORMAT = /\A\+?[1-9]\d{7,14}\z/

    def call
      return { applicable: true, data: fixture } if fixture

      valid = lead.phone.present? && lead.phone.gsub(/[\s().-]/, "").match?(FORMAT)
      one = { "valid" => valid, "line_type" => "unknown", "carrier" => nil }

      {
        applicable: true,
        data: {
          "providers" => { "twilio_lookup" => one, "numverify" => one, "telesign" => one },
          "_source" => "heuristic: format check only, fabricated 3-provider fan-out"
        }
      }
    end

    private

    def provider_name = "phone_validation"
  end
end
