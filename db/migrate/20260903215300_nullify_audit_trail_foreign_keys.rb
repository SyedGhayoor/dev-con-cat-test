class NullifyAuditTrailForeignKeys < ActiveRecord::Migration[8.0]
  # Ledger entries and activity events are an audit trail: they must survive
  # even if the verification_run/lead they reference is later cleaned up, so
  # these FKs nullify on delete instead of restricting/cascading.
  def change
    remove_foreign_key :credit_ledger_entries, :verification_runs
    add_foreign_key :credit_ledger_entries, :verification_runs, on_delete: :nullify

    remove_foreign_key :activity_events, :leads
    add_foreign_key :activity_events, :leads, on_delete: :nullify

    remove_foreign_key :activity_events, :verification_runs
    add_foreign_key :activity_events, :verification_runs, on_delete: :nullify
  end
end
