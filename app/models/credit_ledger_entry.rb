class CreditLedgerEntry < ApplicationRecord
  belongs_to :account
  belongs_to :verification_run, optional: true

  validates :reason, presence: true
end
