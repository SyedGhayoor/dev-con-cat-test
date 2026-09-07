module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account
  end
end
