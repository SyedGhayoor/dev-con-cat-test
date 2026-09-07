class VerificationRun < ApplicationRecord
  include TenantScoped

  STATUSES = %w[pending running completed aborted].freeze

  belongs_to :lead
  belongs_to :policy_version
  has_many :layer_results, dependent: :destroy
  has_one :consensus_verdict, dependent: :destroy
  has_one :consent_certificate, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  # There is no persisted "pending" LayerResult row. Each layer job writes
  # its row directly in a terminal state, so a run is complete once all 10 exist.
  def complete?
    layer_results.count == LayerResult::LAYERS.size
  end
end
