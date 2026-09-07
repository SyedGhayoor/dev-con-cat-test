class CrmContact < ApplicationRecord
  include TenantScoped

  validates :external_crm_id, presence: true, uniqueness: { scope: :account_id }
end
