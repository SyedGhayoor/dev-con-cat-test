module Layers
  # Not a vendor. This is a live query against the buyer's own CRM, so it
  # always runs for real, for both seeded and new leads alike.
  class DuplicateDetection < Base
    def call
      contacts = CrmContact.where(account_id: lead.account_id).to_a
      phone_match = lead.phone.present? ? contacts.find { |c| c.phone.present? && c.phone == lead.phone } : nil
      email_match = lead.email.present? ? contacts.find { |c| c.email.present? && c.email.casecmp?(lead.email) } : nil

      exact = phone_match if phone_match.present? && phone_match == email_match
      data =
        if exact
          { "match_type" => "exact", "matched_crm_id" => exact.external_crm_id }
        elsif phone_match
          { "match_type" => "soft_phone", "matched_crm_id" => phone_match.external_crm_id }
        elsif email_match
          { "match_type" => "soft_email", "matched_crm_id" => email_match.external_crm_id }
        else
          { "match_type" => "none" }
        end

      { applicable: true, data: data }
    end

    private

    def provider_name = "duplicate_detection"
  end
end
