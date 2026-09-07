class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :explicit_account # set directly by jobs/ingestion/seeds; see #account
  attribute :super_admin_override # only ever set inside Admin:: namespace controllers

  delegate :user, to: :session, allow_nil: true

  # Falls back to the logged-in user's account for normal controller
  # requests. Background jobs, the public pixel endpoints, and seeds have no
  # logged-in user at all, so they set Current.account= explicitly instead.
  def account
    explicit_account || user&.account
  end

  def account=(value)
    self.explicit_account = value
  end

  # Raises instead of returning nil so a missing tenant scope fails the
  # request loudly instead of quietly leaking or scoping to nothing.
  def account!
    account || raise(NoTenantContextError, "No Current.account set for this request")
  end

  class NoTenantContextError < StandardError; end
end
