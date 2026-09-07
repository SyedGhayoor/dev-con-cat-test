module Layers
  class BlacklistAlliance < Base
    def call
      return { applicable: true, data: fixture } if fixture

      {
        applicable: true,
        data: {
          "status" => "clean", "match_score" => 0, "sources" => [],
          "_source" => "heuristic: no litigator database available, defaults to clean"
        }
      }
    end

    private

    def provider_name = "blacklist_alliance"
  end
end
