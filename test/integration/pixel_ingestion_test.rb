require "test_helper"

class PixelIngestionTest < ActionDispatch::IntegrationTest
  setup do
    PolicyVersion.find_or_create_by!(account: nil, name: "test-default") do |p|
      p.config = { "hard_stops" => [], "weights" => {}, "thresholds" => { "review" => 30, "reject" => 60 } }
    end

    @account = Account.create!(
      account_id: "acct_ingest_#{SecureRandom.hex(4)}", company_name: "Ingest Test Co",
      plan: "growth", status: "active", monthly_credit_allowance: 10_000, enabled_modules: []
    )
    @pixel = Current.set(account: @account) { Pixel.create!(account: @account, name: "Ingest pixel") }
  end

  test "a lead is always attributed to the pixel's own account, never a client-supplied one" do
    session_id = "sess_#{SecureRandom.hex(6)}"
    post api_pixel_visit_path, params: { session_id: session_id, pixel_id: @pixel.public_id, page_url: "https://x.example/quote" }, as: :json
    assert_response :accepted

    # note there is no account_id field the payload could even spoof.
    # attribution is derived exclusively from pixel_id server-side.
    post api_pixel_leads_path, params: {
      session_id: session_id, pixel_id: @pixel.public_id, form_dwell_ms: 5000,
      fields: { first_name: "A", last_name: "B", email: "a@example.com", phone: "+15551234567" }
    }, as: :json
    assert_response :created

    # Rails resets Current after each dispatched request, so this direct
    # model query (outside a request) needs its own tenant context, same as
    # a background job or console session would.
    lead = Current.set(account: @account) { Lead.find_by(lead_id: JSON.parse(response.body)["lead_id"]) }
    assert_equal @account.id, lead.account_id
  end

  test "posting a lead without a prior /visit for that session is rejected" do
    post api_pixel_leads_path, params: {
      session_id: "sess_never_visited", pixel_id: @pixel.public_id,
      fields: { first_name: "A", last_name: "B", email: "a@example.com", phone: "+15551234567" }
    }, as: :json

    assert_response :unprocessable_content
    assert_equal 0, Current.set(account: @account) { Lead.count }
  end

  test "replaying the same (pixel_id, session_id) is idempotent, not a second lead" do
    session_id = "sess_#{SecureRandom.hex(6)}"
    post api_pixel_visit_path, params: { session_id: session_id, pixel_id: @pixel.public_id }, as: :json

    lead_params = {
      session_id: session_id, pixel_id: @pixel.public_id,
      fields: { first_name: "A", last_name: "B", email: "a@example.com", phone: "+15551234567" }
    }
    post api_pixel_leads_path, params: lead_params, as: :json
    first_lead_id = JSON.parse(response.body)["lead_id"]

    post api_pixel_leads_path, params: lead_params, as: :json
    assert_response :ok # 200, not 201: no new resource created
    second_lead_id = JSON.parse(response.body)["lead_id"]

    assert_equal first_lead_id, second_lead_id
    assert_equal 1, Current.set(account: @account) { Lead.count }
  end

  test "an unknown pixel_id is rejected before any lead is created" do
    post api_pixel_visit_path, params: { session_id: "sess_x", pixel_id: "px_does_not_exist" }, as: :json
    assert_response :not_found

    post api_pixel_leads_path, params: { session_id: "sess_x", pixel_id: "px_does_not_exist", fields: {} }, as: :json
    assert_response :not_found
    assert_equal 0, Current.set(super_admin_override: true) { Lead.count }
  end

  test "the activity stream requires the capability token, not just the lead_id" do
    session_id = "sess_#{SecureRandom.hex(6)}"
    post api_pixel_visit_path, params: { session_id: session_id, pixel_id: @pixel.public_id }, as: :json
    post api_pixel_leads_path, params: {
      session_id: session_id, pixel_id: @pixel.public_id,
      fields: { first_name: "A", last_name: "B", email: "a@example.com", phone: "+15551234567" }
    }, as: :json
    lead_id = JSON.parse(response.body)["lead_id"]

    get api_pixel_lead_activity_path(lead_id: lead_id), params: { token: "totally-wrong-token" }
    assert_response :forbidden
  end
end
