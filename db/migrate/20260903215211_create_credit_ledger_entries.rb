class CreateCreditLedgerEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_ledger_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :verification_run, foreign_key: true
      t.string :layer
      t.integer :delta, null: false # negative for a debit
      t.string :reason, null: false
      t.integer :balance_after, null: false

      t.datetime :created_at, null: false
    end
    add_index :credit_ledger_entries, [:account_id, :created_at]
  end
end
