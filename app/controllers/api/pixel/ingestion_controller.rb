module Api
  module Pixel
    class IngestionController < Api::BaseController
      before_action :find_pixel

      # POST /api/pixel/visit
      # Records the site-visit beacon so the vpn_proxy layer can later compare
      # it to the submit IP. Idempotent on session_id: a page that fires this
      # more than once (e.g. a retry) just updates the same row.
      def visit
        session_id = params.require(:session_id)

        capture_session = CaptureSession.find_or_initialize_by(session_id: session_id)
        capture_session.assign_attributes(
          account: @pixel.account,
          pixel: @pixel,
          page_url: params[:page_url],
          referrer: params[:referrer],
          user_agent: request.user_agent,
          visit_ip: request.remote_ip,
          started_at: parse_time(params[:started_at]) || Time.current
        )
        capture_session.save!

        head :accepted
      end

      # POST /api/pixel/leads
      # account_id is never read from the payload. It's derived exclusively
      # from the pixel the request authenticates against (find_pixel below).
      def create_lead
        session_id = params.require(:session_id)
        capture_session = @pixel.capture_sessions.find_by(session_id: session_id)

        unless capture_session
          return render json: { error: "no_matching_visit_session" }, status: :unprocessable_entity
        end

        # Idempotent on (pixel_id, session_id): a replayed POST returns the
        # already-created lead instead of fabricating a duplicate/re-billing.
        if (existing = @pixel.leads.find_by(capture_session: capture_session))
          return render json: { lead_id: existing.lead_id, activity_token: existing.activity_token }, status: :ok
        end

        fields = params[:fields].is_a?(ActionController::Parameters) ? params[:fields].to_unsafe_h : {}

        lead = @pixel.leads.create!(
          account: @pixel.account,
          capture_session: capture_session,
          first_name: fields["first_name"],
          last_name: fields["last_name"],
          email: fields["email"],
          phone: fields["phone"],
          submit_ip: request.remote_ip,
          landing_page_url: capture_session.page_url,
          trusted_form_cert_url: trusted_form_cert_url_for(fields),
          form_dwell_ms: params[:form_dwell_ms],
          submitted_at: parse_time(params[:submitted_at]) || Time.current,
          raw_fields: fields
        )

        ActivityEvent.record!(account: lead.account, lead: lead, event_type: "lead_submitted",
                               payload: { pixel_id: @pixel.public_id })

        VerificationRuns::Start.call(lead)

        render json: { lead_id: lead.lead_id, activity_token: lead.activity_token }, status: :created
      end

      private

      # No tenant context exists yet at this point. The pixel_id is the
      # thing that establishes one, so this is the one deliberate unscoped
      # lookup in this controller. Everything after this sets Current.account
      # from the resolved pixel and runs fully tenant-scoped from then on.
      def find_pixel
        @pixel = ::Pixel.unscoped.active.find_by!(public_id: params.require(:pixel_id))
        Current.account = @pixel.account
      end

      # The demo landing page has no real TrustedForm integration, but it
      # does have the exact TCPA consent checkbox TrustedForm exists to
      # capture. If the pixel already forwards a real cert URL, trust that;
      # otherwise synthesize one only when the visitor actually checked
      # consent, so the trustedform layer's verdict genuinely reflects what
      # the visitor did on the page rather than being hardcoded either way.
      def trusted_form_cert_url_for(fields)
        explicit = fields["trusted_form_cert_url"] || fields["xxTrustedFormCertUrl"]
        return explicit if explicit.present?

        consented = ActiveModel::Type::Boolean.new.cast(fields["consent"])
        consented ? "https://cert.trustedform.example/#{SecureRandom.hex(16)}" : nil
      end

      def parse_time(value)
        value.present? ? Time.zone.parse(value.to_s) : nil
      rescue ArgumentError
        nil
      end
    end
  end
end
