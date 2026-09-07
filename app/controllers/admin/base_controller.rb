module Admin
  # Every action in this namespace runs with cross-account power. That power
  # is confined to this one controller subtree: Current.account stays nil for
  # a super_admin (see Current#account), so any code path outside Admin::
  # that uses the normal current_account.foo pattern still raises instead of
  # silently seeing everything. Current.super_admin_override is only ever
  # flipped on here, and only for the duration of the request.
  class BaseController < ApplicationController
    skip_after_action :verify_authorized, :verify_policy_scoped
    before_action :require_super_admin!

    private

    def require_super_admin!
      render plain: "Not found", status: :not_found unless Current.user&.super_admin?
      Current.super_admin_override = true if Current.user&.super_admin?
    end
  end
end
