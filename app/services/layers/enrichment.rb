module Layers
  class Enrichment < Base
    def call
      return { applicable: true, data: fixture } if fixture

      none = { "matched" => false, "address" => nil, "age_band" => nil, "match_to_lead" => false }

      {
        applicable: true,
        data: {
          "audiencelabs" => none,
          "bytemine" => none.merge("household_income" => nil),
          "_source" => "heuristic: no identity enrichment database available"
        }
      }
    end

    private

    def provider_name = "enrichment"
  end
end
