class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  after_action :verify_authorized, except: :index, unless: :skip_pundit_verification?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit_verification?

  # 404, not 403: don't confirm to an attacker that a cross-tenant record exists.
  rescue_from Pundit::NotAuthorizedError, with: :render_not_found
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from Current::NoTenantContextError, with: :render_not_found

  helper_method :current_account, :current_user_role

  private

  # Pundit calls pundit_user (defaults to `current_user`, which we don't
  # define). Auth state lives on Current, not a controller method.
  def pundit_user
    Current.user
  end

  # The single sanctioned entry point tenant-scoped controllers use to load
  # records: current_account.leads.find(...), never Lead.find(...) directly.
  def current_account
    Current.account!
  end

  def current_user_role
    Current.user&.role
  end

  def skip_pundit_verification?
    false
  end

  def render_not_found
    render plain: "Not found", status: :not_found
  end
end
