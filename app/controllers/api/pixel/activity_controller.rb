module Api
  module Pixel
    # SSE stream of layer_result / final_verdict events for one lead.
    #
    # Gated by the lead's activity_token (issued in the POST /leads response),
    # not by the bare lead_id. Lead_ids are sequential-ish and this channel
    # is inherently unauthenticated (a site visitor has no session), so the
    # token is what actually proves "this connection is entitled to watch
    # this lead's activity."
    class ActivityController < Api::BaseController
      include ActionController::Live

      HEARTBEAT_EVERY = 25.seconds
      MAX_DURATION = 2.minutes

      def stream
        lead = Lead.unscoped.find_by(lead_id: params[:lead_id])
        return render json: { error: "not_found" }, status: :not_found unless lead
        return render json: { error: "invalid_token" }, status: :forbidden unless lead.activity_token_valid?(params[:token])

        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"

        sse = ActionController::Live::SSE.new(response.stream, retry: 3000)
        queue = LeadActivityBroadcaster.subscribe(lead.lead_id)
        deadline = MAX_DURATION.from_now

        begin
          loop do
            event = begin
              Timeout.timeout(HEARTBEAT_EVERY) { queue.pop }
            rescue Timeout::Error
              sse.write({}, event: "heartbeat")
              next
            end

            break if write_event(sse, event) == :final
            break if Time.current > deadline
          end
        rescue IOError
          nil # client disconnected; nothing left to do
        ensure
          LeadActivityBroadcaster.unsubscribe(lead.lead_id, queue)
          sse.close
        end
      end

      private

      def write_event(sse, event)
        payload = event[:payload]

        case event[:event_type]
        when "layer_completed"
          sse.write({ layer: payload["layer"], state: payload["state"], data: payload["data"] }, event: "layer_result")
          nil
        when "verdict_issued"
          sse.write({ verdict: payload["verdict"].upcase, score: payload["score"], reasons: payload["reasons"] }, event: "final_verdict")
          :final
        end
      end
    end
  end
end
