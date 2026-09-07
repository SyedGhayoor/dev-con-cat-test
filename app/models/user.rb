class User < ApplicationRecord
  ROLES = %w[super_admin account_admin member].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :account, optional: true # only nil for super_admin

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :role, inclusion: { in: ROLES }
  validates :account_id, presence: true, unless: :super_admin?
  validates :account_id, absence: true, if: :super_admin?

  def super_admin? = role == "super_admin"
  def account_admin? = role == "account_admin"
  def member? = role == "member"
end
