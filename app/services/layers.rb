module Layers
  ALL = {
    "vpn_proxy" => "Layers::VpnProxy",
    "anura" => "Layers::Anura",
    "trustedform" => "Layers::Trustedform",
    "blacklist_alliance" => "Layers::BlacklistAlliance",
    "dnc" => "Layers::Dnc",
    "phone_validation" => "Layers::PhoneValidation",
    "email_validation" => "Layers::EmailValidation",
    "enrichment" => "Layers::Enrichment",
    "duplicate_detection" => "Layers::DuplicateDetection",
    "voice" => "Layers::Voice"
  }.freeze

  def self.for(layer)
    ALL.fetch(layer.to_s).constantize
  end
end
