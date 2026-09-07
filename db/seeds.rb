require "json"

MOCK_DIR = Rails.root.join("mock-data")

def load_json(*parts)
  JSON.parse(File.read(MOCK_DIR.join(*parts)))
end

puts "== module costs =="
accounts_data = load_json("accounts.json")
accounts_data.fetch("module_costs_in_credits").each do |layer, cost|
  ModuleCost.find_or_create_by!(layer: layer) { |m| m.cost_in_credits = cost }
end
ModuleCost.reset_cache!
puts "  #{ModuleCost.count} module costs"

puts "== accounts =="
accounts_data.fetch("accounts").each do |a|
  Account.find_or_create_by!(account_id: a["account_id"]) do |acct|
    acct.company_name = a["company_name"]
    acct.plan = a["plan"]
    acct.status = a["status"]
    acct.monthly_credit_allowance = a["monthly_credit_allowance"]
    acct.credits_used_this_cycle = a["credits_used_this_cycle"]
    acct.cycle_start = a["cycle_start"]
    acct.cycle_end = a["cycle_end"]
    acct.avg_daily_burn = a["avg_daily_burn"]
    acct.billing_contact = a["billing_contact"]
    acct.enabled_modules = a["enabled_modules"]
  end
end
puts "  #{Account.count} accounts"

puts "== users =="
load_json("users.json").fetch("users").each do |u|
  account = u["account_id"] && Account.find_by!(account_id: u["account_id"])
  User.find_or_create_by!(email_address: u["email"]) do |user|
    user.account = account
    user.role = u["role"]
    user.name = u["name"]
    user.password = u["placeholder_password"]
  end
end
puts "  #{User.count} users"

puts "== pixels (derived from leads.json) =="
leads_data = load_json("leads.json").fetch("leads")

pixel_groups = leads_data.group_by { |l| l["pixel_id"] }
pixel_groups.each do |pixel_id, rows|
  account = Account.find_by!(account_id: rows.first["account_id"])
  campaign_names = rows.map { |r| r["campaign"] }.compact.uniq
  landing_pages = rows.map { |r| r["landing_page_url"] }.compact.uniq

  # Pixel is tenant-scoped now, so seeding it needs a tenant context set.
  # Current.set runs the block and resets afterward, same as a request.
  Current.set(account: account) do
    Pixel.find_or_create_by!(public_id: pixel_id) do |pixel|
      pixel.account = account
      pixel.name = campaign_names.first&.split("-")&.first&.capitalize || "Imported pixel"
      pixel.allowed_landing_pages = landing_pages
      pixel.active = true
    end
  end
end
puts "  #{Current.set(super_admin_override: true) { Pixel.count }} pixels"

puts "== leads (+ synthetic capture sessions) =="
leads_data.each do |l|
  account = Account.find_by!(account_id: l["account_id"])

  Current.set(account: account) do
    pixel = Pixel.find_by!(public_id: l["pixel_id"])
    next if Lead.exists?(lead_id: l["lead_id"])

    submitted_at = Time.zone.parse(l["captured_at"])
    started_at = submitted_at - ((l["form_dwell_ms"] || 0).to_i / 1000.0).seconds

    capture_session = CaptureSession.create!(
      account: account,
      pixel: pixel,
      session_id: "sess_seed_#{l["lead_id"].delete_prefix("L-")}",
      page_url: l["landing_page_url"],
      referrer: nil,
      user_agent: l["user_agent"],
      visit_ip: l["ip_address"],
      started_at: started_at
    )

    Lead.create!(
      account: account,
      pixel: pixel,
      capture_session: capture_session,
      lead_id: l["lead_id"],
      first_name: l["first_name"],
      last_name: l["last_name"],
      email: l["email"],
      phone: l["phone"],
      submit_ip: l["ip_address"],
      landing_page_url: l["landing_page_url"],
      campaign: l["campaign"],
      trusted_form_cert_url: l["trusted_form_cert_url"],
      form_dwell_ms: l["form_dwell_ms"],
      submitted_at: submitted_at,
      raw_fields: l.slice("first_name", "last_name", "email", "phone")
      # NB: expected_verdict is intentionally NOT imported anywhere. The
      # consensus engine must never have access to it, even as seed data.
    )
  end
end
puts "  #{Current.set(super_admin_override: true) { Lead.count }} leads"

puts "== buyer CRM records =="
load_json("buyers_crm.json").fetch("crm_records").each do |account_id, records|
  account = Account.find_by!(account_id: account_id)
  Current.set(account: account) do
    records.each do |r|
      CrmContact.find_or_create_by!(account: account, external_crm_id: r["crm_id"]) do |c|
        c.first_name = r["first_name"]
        c.last_name = r["last_name"]
        c.email = r["email"]
        c.phone = r["phone"]
        c.crm_created_at = r["created_at"]
      end
    end
  end
end
puts "  #{Current.set(super_admin_override: true) { CrmContact.count }} CRM contacts"

puts "== default policy =="
# NB: weight keys here must exactly match the SIGNALS/HARD_STOPS codes in
# app/services/consensus_engine.rb. A key present in one but not the other
# is a silent no-op, not an error, so this block always overwrites config
# (not just on first create) to keep the two from drifting apart again.
policy = PolicyVersion.find_or_initialize_by(account: nil, name: "platform-default")
policy.version = 1
policy.active = true
policy.config = {
  "hard_stops" => %w[litigator_confirmed dnc_not_callable exact_duplicate trustedform_mismatch trustedform_expired],
  "weights" => {
    "vpn_or_proxy_detected" => 15,
    "site_visit_ip_mismatch" => 20,
    "vpn_high_risk" => 15,
    "vpn_medium_risk" => 3,
    "anura_suspect" => 20,
    "anura_bad" => 45,
    "litigator_suspected" => 35,
    "trustedform_not_found" => 20,
    "phone_providers_disagree" => 25,
    "phone_voip_flagged" => 10,
    "email_providers_disagree" => 25,
    "email_both_undeliverable" => 35,
    "email_disposable" => 30,
    "email_high_fraud_score" => 15,
    "enrichment_sources_disagree" => 20,
    "enrichment_neither_matched" => 10,
    "soft_duplicate" => 20,
    "dnc_callback_window_closed" => 10,
    "voice_reused_actor" => 55,
    "voice_synthetic" => 55
  },
  "thresholds" => { "review" => 30, "reject" => 60 }
}
policy.save!
puts "  #{PolicyVersion.count} policy versions"

puts "== running the 12 seed leads through the real verification pipeline =="
# Deliberately the exact same entry point the pixel's ingestion endpoint
# uses (VerificationRuns::Start). Proves the consensus engine derives
# these from the mock provider data rather than being special-cased for
# seeding, and leaves the CRM/certificates/super-admin dashboard populated
# immediately after `db:seed`.
# This one query spans every account, so it uses the same super_admin
# escape hatch the Admin:: namespace uses, a deliberate, visible opt-out.
pending_leads = Current.set(super_admin_override: true) do
  Lead.left_joins(:verification_runs).where(verification_runs: { id: nil }).to_a
end

pending_leads.each do |lead|
  Current.set(account: lead.account) do
    run = VerificationRuns::Start.call(lead)
    60.times { break if run.reload.status == "completed"; sleep 0.1 }
  end
end
Current.set(super_admin_override: true) do
  puts "  #{VerificationRun.where(status: "completed").count}/#{Lead.count} leads verified"
end

puts "Done."
