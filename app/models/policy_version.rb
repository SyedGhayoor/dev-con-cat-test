class PolicyVersion < ApplicationRecord
  belongs_to :account, optional: true # nil => platform default policy
  has_many :verification_runs
  has_many :consensus_verdicts

  validates :name, presence: true

  def hard_stops   = config.fetch("hard_stops", [])
  def weights      = config.fetch("weights", {})
  def thresholds   = config.fetch("thresholds", {})

  def self.default_for(account)
    account.policy_versions.find_by(active: true) ||
      where(account_id: nil, active: true).order(version: :desc).first
  end
end
