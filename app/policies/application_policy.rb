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

    def resolve
      user.super_admin? ? scope.all : scope.where(account_id: user.account_id)
    end
  end

  private

  def same_account?
    user.super_admin? || (user.account_id.present? && record.account_id == user.account_id)
  end

  def account_admin_or_above?
    user.super_admin? || (user.account_admin? && same_account?)
  end
end
