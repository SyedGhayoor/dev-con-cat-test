module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account

    # Structural isolation, not just convention: any query on a tenant-owned
    # model raises if no tenant context is set, instead of silently scoping
    # to nothing (or, worse, succeeding unscoped). super_admin_override is
    # the one deliberate escape hatch, and it's only ever set inside the
    # Admin:: namespace. Anything else that genuinely needs to bypass this
    # (a public certificate-verify link, an anonymous pixel visitor's own
    # activity stream) calls .unscoped explicitly at that one call site,
    # which is a visible, deliberate opt-out rather than an accident.
    default_scope do
      if Current.super_admin_override
        unscoped
      else
        where(account_id: Current.account!.id)
      end
    end
  end
end
