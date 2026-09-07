module Layers
  # Every layer adapter does the same thing: replay the exact mock fixture
  # for the 12 seeded lead_ids, otherwise fall back to a small heuristic
  # computed from the lead's own real data. The fallback is not a real
  # vendor integration. It's what lets the live pixel demo produce real,
  # input-driven results for leads that were never in mock-data/providers/.
  class Base
    def self.call(lead) = new(lead).call

    def initialize(lead)
      @lead = lead
    end

    private

    attr_reader :lead

    def fixture
      ProviderFixtures.for(provider_name, lead.lead_id)
    end

    def provider_name
      raise NotImplementedError
    end
  end
end
