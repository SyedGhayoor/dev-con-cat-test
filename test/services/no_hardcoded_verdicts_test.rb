require "test_helper"

# A literal, mechanical proof rather than a claim: the consensus engine (and
# nothing else under app/) is allowed to reference the seed data's
# expected_verdict hint. If this ever starts passing because someone added a
# `if lead_id == "L-1002"` shortcut instead of deriving the verdict from real
# layer data, this test catches it. See docs/data-contracts.md, which is
# explicit that the hint must never be read by the engine.
class NoHardcodedVerdictsTest < ActiveSupport::TestCase
  test "expected_verdict is never referenced anywhere under app/" do
    offenders = Dir[Rails.root.join("app/**/*.rb")].select do |file|
      File.read(file).include?("expected_verdict")
    end

    assert_empty offenders, "these files reference expected_verdict and shouldn't: #{offenders.join(", ")}"
  end

  test "no seed lead_id is referenced by the consensus engine or layer adapters" do
    seed_lead_ids = (1001..1012).map { |n| "L-#{n}" }
    engine_files = Dir[Rails.root.join("app/services/consensus_engine.rb")] +
                   Dir[Rails.root.join("app/services/layers/**/*.rb")]

    offenders = engine_files.select do |file|
      contents = File.read(file)
      seed_lead_ids.any? { |id| contents.include?(id) }
    end

    assert_empty offenders, "these files reference a specific seed lead_id and shouldn't: #{offenders.join(", ")}"
  end
end
