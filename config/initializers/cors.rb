Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # The pixel is embedded on arbitrary third-party buyer landing pages, so
    # the origin can't be allowlisted, so attribution/auth happens via the
    # pixel_id to account lookup and the activity token, not CORS origin
    # checks. Scoped strictly to the public ingestion + activity paths.
    origins "*"
    resource "/api/pixel/*",
      headers: :any,
      methods: [:get, :post, :options],
      credentials: false
  end
end
