module Layers
  class EmailValidation < Base
    DISPOSABLE_DOMAINS = %w[mailinator.com tempmail.com guerrillamail.com 10minutemail.com mail-tempz.example].freeze

    def call
      return { applicable: true, data: fixture } if fixture

      email = lead.email.to_s
      well_formed = email.match?(URI::MailTo::EMAIL_REGEXP)
      domain = email.split("@").last.to_s.downcase
      disposable = DISPOSABLE_DOMAINS.any? { |d| domain == d }
      deliverable = well_formed && !disposable
      fraud_score = disposable ? 90 : (well_formed ? 10 : 60)
      one = { "deliverable" => deliverable, "disposable" => disposable, "fraud_score" => fraud_score }

      {
        applicable: true,
        data: {
          "providers" => { "zerobounce" => one, "neverbounce" => one },
          "_source" => "heuristic: format + denylist check only, fabricated 2-provider fan-out"
        }
      }
    end

    private

    def provider_name = "email_validation"
  end
end
