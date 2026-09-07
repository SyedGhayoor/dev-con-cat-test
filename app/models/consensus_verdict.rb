class ConsensusVerdict < ApplicationRecord
  include TenantScoped

  VERDICTS = %w[accept review reject].freeze

  belongs_to :verification_run
  belongs_to :policy_version

  validates :verdict, inclusion: { in: VERDICTS }
end
