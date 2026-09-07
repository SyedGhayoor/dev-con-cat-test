class ConsentCertificate < ApplicationRecord
  include TenantScoped

  belongs_to :lead
  belongs_to :verification_run

  before_validation :generate_certificate_uid, on: :create

  validates :certificate_uid, presence: true, uniqueness: true
  validates :content_hash, presence: true

  def verify
    content_hash == self.class.hash_for(snapshot)
  end

  # jsonb doesn't preserve key order on save, so hashing a reloaded snapshot's
  # #to_json directly isn't stable: same content, different byte order,
  # different hash. Sorting keys first makes the hash depend only on content.
  def self.hash_for(snapshot)
    Digest::SHA256.hexdigest(canonicalize(snapshot).to_json)
  end

  def self.canonicalize(value)
    case value
    when Hash
      value.map { |k, v| [k.to_s, canonicalize(v)] }.sort_by(&:first).to_h
    when Array
      value.map { |v| canonicalize(v) }
    else
      value
    end
  end

  private

  def generate_certificate_uid
    self.certificate_uid ||= "cert_#{SecureRandom.hex(10)}"
  end
end
