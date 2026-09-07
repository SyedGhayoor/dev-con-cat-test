module Api
  module Pixel
    # SSE stream of layer_result / final_verdict events for one lead.
    #
    # Gated by the lead's activity_token (issued in the POST /leads response),
    # not by the bare lead_id. Lead_ids are sequential-ish and this channel
    # is inherently unauthenticated (a site visitor has no session), so the
    # token is what actually proves "this connection is entitled to watch
    # this lead's activity."
    #
    # Delivery is a cursor-based poll over ActivityEvent, not an in-process
    # pub/sub queue. That means this stream depends on nothing but the
    # database: it survives the app restarting mid-verification, and it
    # works the same way whether there's one Puma process or several, with
    # no Redis or other broker in between.
    class ActivityController < Api::BaseController
      include ActionController::Live

      POLL_INTERVAL = 0.3
      HEARTBEAT_EVERY = 25.seconds
      MAX_DURATION = 2.minutes

      def stream
        # No tenant context exists yet. The activity_token is what proves
        # this connection is entitled to this one lead, so this is a
        # deliberate unscoped lookup, same as find_pixel in IngestionController.
        lead = Lead.unscoped.find_by(lead_id: params[:lead_id])
        return render json: { error: "not_found" }, status: :not_found unless lead
        return render json: { error: "invalid_token" }, status: :forbidden unless lead.activity_token_valid?(params[:token])

        Current.account = lead.account

        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"

        sse = ActionController::Live::SSE.new(response.stream, retry: 3000)

        begin
          poll_and_stream(lead, sse)
        rescue IOError
          nil # client disconnected; nothing left to do
        ensure
          sse.close
        end
      end

      private

      def poll_and_stream(lead, sse)
        cursor = 0
        deadline = MAX_DURATION.from_now
        next_heartbeat_at = HEARTBEAT_EVERY.from_now

        loop do
          new_events = lead.activity_events
                            .where(event_type: %w[layer_completed verdict_issued])
                            .where("id > ?", cursor)
                            .order(:id)
                            .to_a

          new_events.each do |event|
            cursor = event.id
            return if write_event(sse, event) == :final
          end

          return if Time.current > deadline

          if Time.current > next_heartbeat_at
            sse.write({}, event: "heartbeat")
            next_heartbeat_at = HEARTBEAT_EVERY.from_now
          end

          sleep POLL_INTERVAL
        end
      end

      def write_event(sse, event)
        payload = event.payload

        case event.event_type
        when "layer_completed"
          sse.write({ layer: payload["layer"], state: payload["state"], data: payload["data"] }, event: "layer_result")
          nil
        when "verdict_issued"
          # The stored ActivityEvent keeps the raw verdict ("accept"); the
          # pixel JS matches on the uppercase form ("ACCEPT"), same as before.
          sse.write({ verdict: payload["verdict"].upcase, score: payload["score"], reasons: payload["reasons"] }, event: "final_verdict")
          :final
        end
      end
    end
  end
end
