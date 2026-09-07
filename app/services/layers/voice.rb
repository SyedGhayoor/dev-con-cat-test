module Layers
  class Voice < Base
    def call
      if (f = fixture)
        return { applicable: f["has_sample"] == true, data: f }
      end

      # the pixel never captures an audio sample, so this is not_applicable
      # for every lead outside the seeded mock-data scenarios
      { applicable: false, data: { "has_sample" => false, "verdict" => nil } }
    end

    private

    def provider_name = "voice"
  end
end
