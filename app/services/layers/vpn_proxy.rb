module Layers
  class VpnProxy < Base
    def call
      return { applicable: true, data: fixture } if fixture

      visit_ip = lead.capture_session&.visit_ip
      submit_ip = lead.submit_ip
      matches = visit_ip.blank? || visit_ip == submit_ip

      {
        applicable: true,
        data: {
          "is_vpn" => false, "is_proxy" => false, "is_tor" => false, "is_datacenter" => false,
          "site_visit_ip_matches_submit_ip" => matches,
          "risk" => matches ? "low" : "medium",
          "_source" => "heuristic: real visit-vs-submit IP compare, no VPN/proxy vendor available"
        }
      }
    end

    private

    def provider_name = "vpn_proxy"
  end
end
