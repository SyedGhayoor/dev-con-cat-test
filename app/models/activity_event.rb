class ActivityEvent < ApplicationRecord
  include TenantScoped

  belongs_to :lead, optional: true
  belongs_to :verification_run, optional: true

  validates :event_type, presence: true
  validates :occurred_at, presence: true

  BROADCAST_EVENT_TYPES = %w[layer_completed verdict_issued].freeze

  after_create_commit :broadcast_to_live_stream, if: -> { BROADCAST_EVENT_TYPES.include?(event_type) }

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

  private

  def broadcast_to_live_stream
    LeadActivityBroadcaster.publish(lead.lead_id, event_type: event_type, payload: payload)
  end
end
