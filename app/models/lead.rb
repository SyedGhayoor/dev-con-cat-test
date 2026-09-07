class Lead < ApplicationRecord
  include TenantScoped

  belongs_to :pixel
  belongs_to :capture_session, optional: true
  has_many :verification_runs, dependent: :destroy
  has_many :consent_certificates, dependent: :destroy
  has_many :activity_events, dependent: :destroy

  before_validation :generate_lead_id, on: :create
  before_validation :generate_activity_token, on: :create

  validates :lead_id, presence: true, uniqueness: true
  validates :submitted_at, presence: true

  def current_run
    verification_runs.order(created_at: :desc).first
  end

  def activity_token_valid?(token)
    return false if activity_token.blank? || token.blank?
    return false if activity_token_expires_at.present? && activity_token_expires_at.past?

    ActiveSupport::SecurityUtils.secure_compare(activity_token, token)
  end

  private

  def generate_lead_id
    self.lead_id ||= "L-#{SecureRandom.hex(5)}"
  end

  def generate_activity_token
    self.activity_token ||= SecureRandom.urlsafe_base64(32)
    self.activity_token_expires_at ||= 2.hours.from_now
  end
end
