class Pixel < ApplicationRecord
  include TenantScoped

  # leads reference capture_sessions by FK, so they must be destroyed first.
  has_many :leads, dependent: :destroy
  has_many :capture_sessions, dependent: :destroy

  scope :active, -> { where(active: true) }

  before_validation :generate_public_id, on: :create

  validates :name, presence: true
  validates :public_id, presence: true, uniqueness: true

  # Modules this pixel may exercise are capped by what the account has paid
  # for; there's no pixel-level override of the account's enabled_modules.
  def enabled_modules
    account.enabled_modules
  end

  # The exact copy-paste snippet a buyer embeds on their landing page.
  def embed_snippet(host:)
    base = host.sub(%r{/\z}, "")
    <<~HTML
      <script async src="#{base}/super-pixel.js"
              data-pixel-id="#{public_id}"
              data-endpoint="#{base}/api/pixel"></script>
    HTML
  end

  private

  def generate_public_id
    self.public_id ||= "px_#{SecureRandom.hex(6)}"
  end
end
