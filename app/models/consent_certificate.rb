class ConsentCertificate < ApplicationRecord
  include TenantScoped

  belongs_to :lead
  belongs_to :verification_run

  before_validation :generate_certificate_uid, on: :create
  before_create :assign_chain_position

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

  # A single hash only proves one certificate's own content wasn't edited.
  # It says nothing if the row is deleted outright, or two certificates are
  # swapped. Walking the chain catches both: each certificate names the
  # previous one's hash, so a missing or reordered link breaks the chain
  # visibly instead of just quietly disappearing.
  def self.chain_intact?(account)
    certificates = unscoped.where(account_id: account.id).order(:sequence_number).to_a

    certificates.each_with_index do |certificate, index|
      expected_previous_hash = index.zero? ? nil : certificates[index - 1].content_hash
      return false if certificate.previous_hash != expected_previous_hash
      return false unless certificate.verify
    end

    true
  end

  private

  def generate_certificate_uid
    self.certificate_uid ||= "cert_#{SecureRandom.hex(10)}"
  end

  # Locks the account while reading the last link in its chain so two
  # certificates issued for the same account at the same moment (two leads
  # finishing verification in parallel) can't both compute the same next
  # position. Same race Account#debit_credits! guards against.
  def assign_chain_position
    account.with_lock do
      previous = self.class.unscoped.where(account_id: account_id).order(sequence_number: :desc).first
      self.sequence_number = (previous&.sequence_number || 0) + 1
      self.previous_hash = previous&.content_hash
    end
  end
end
