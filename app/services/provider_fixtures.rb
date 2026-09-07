# Reads the mock vendor fixtures directly from mock-data/providers/*.json,
# keyed by lead_id, memoized per process. This is the "serve them from a
# small internal service" option instead of importing every response into its own table.
class ProviderFixtures
  def self.for(provider, lead_id)
    data(provider)["results"][lead_id]
  end

  def self.data(provider)
    @data ||= {}
    @data[provider.to_s] ||= JSON.parse(
      File.read(Rails.root.join("mock-data", "providers", "#{provider}.json"))
    )
  end
end
