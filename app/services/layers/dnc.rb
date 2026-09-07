module Layers
  class Dnc < Base
    def call
      return { applicable: true, data: fixture } if fixture

      {
        applicable: true,
        data: {
          "dnc_status" => "callable", "national_dnc" => false, "state_dnc" => false,
          "internal_dnc" => false, "callback_window_open" => true,
          "_source" => "heuristic: no DNC registry available, defaults to callable"
        }
      }
    end

    private

    def provider_name = "dnc"
  end
end
