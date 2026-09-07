class ActivityEvent < ApplicationRecord
  include TenantScoped

  belongs_to :lead, optional: true
  belongs_to :verification_run, optional: true

  validates :event_type, presence: true
  validates :occurred_at, presence: true

  def self.record!(account:, event_type:, lead: nil, verification_run: nil, payload: {})
    create!(
      account: account,
      lead: lead,
      verification_run: verification_run,
      event_type: event_type,
      payload: payload,
      occurred_at: Time.current
    )
  end
end
