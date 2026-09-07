class PixelPolicy < ApplicationPolicy
  def index? = user.account_id.present? || user.super_admin?

  # Per users.json's role note, both account_admin and member manage pixels;
  # only account-level settings (users/billing) are account_admin-only.
  # record.account_id is already set by `current_account.pixels.new`, even
  # pre-save, so same_account? covers create? too.
  def create? = user.account_id.present? && same_account?
  def update? = user.account_id.present? && same_account?
  def destroy? = user.account_id.present? && same_account?
end
