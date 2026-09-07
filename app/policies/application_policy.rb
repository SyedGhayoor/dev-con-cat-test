class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = same_account?
  def create? = account_admin_or_above?
  def update? = account_admin_or_above?
  def destroy? = account_admin_or_above?

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # TenantScoped's default_scope is the actual enforcement boundary now.
    # It raises for a super_admin outside the Admin:: namespace (they have no
    # account), so `scope.all` here can never accidentally hand back every
    # account's records the way it could before that existed.
    def resolve
      scope.where(account_id: user.account_id)
    end
  end

  private

  # Re-derives tenant ownership from the record itself, independent of how it
  # was fetched. The backstop for a controller that forgot to scope a query.
  def same_account?
    user.super_admin? || (user.account_id.present? && record.account_id == user.account_id)
  end

  def account_admin_or_above?
    user.super_admin? || (user.account_admin? && same_account?)
  end
end
