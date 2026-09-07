class LayerResult < ApplicationRecord
  include TenantScoped

  LAYERS = %w[
    vpn_proxy anura trustedform blacklist_alliance dnc
    phone_validation email_validation enrichment duplicate_detection voice
  ].freeze

  # not_enabled / not_applicable / returned_verdict is the three-way split
  # the assignment calls out; skipped_insufficient_credits is a fourth so
  # credit exhaustion never gets confused with "never enabled."
  STATES = %w[not_enabled not_applicable returned_verdict skipped_insufficient_credits].freeze

  belongs_to :verification_run

  validates :layer, inclusion: { in: LAYERS }
  validates :state, inclusion: { in: STATES }
  validates :layer, uniqueness: { scope: :verification_run_id }

  def ran? = state == "returned_verdict"
end
