class CaptureSession < ApplicationRecord
  include TenantScoped

  belongs_to :pixel
  has_many :leads

  validates :session_id, presence: true, uniqueness: true
  validates :started_at, presence: true
end
