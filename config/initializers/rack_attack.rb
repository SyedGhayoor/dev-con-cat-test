class Rack::Attack
  # The pixel endpoints are necessarily unauthenticated (a random site visitor
  # has no session), so IP-based throttling is the first line of defense
  # against spam/replay. (A per-pixel_id throttle would need to peek and
  # rewind the JSON body in Rack middleware, not worth the fragility here;
  # the /leads idempotency key on (pixel_id, session_id) already makes a
  # replay harmless at the application layer regardless of rate.)
  throttle("pixel/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/pixel/")
  end

  self.throttled_responder = lambda do |request|
    [429, { "Content-Type" => "application/json" }, [{ error: "rate_limited" }.to_json]]
  end
end
