class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :account_id, null: false # public slug, e.g. "acct_solarpro"
      t.string :company_name, null: false
      t.string :plan, null: false, default: "starter"
      t.string :status, null: false, default: "active" # active | past_due | suspended
      t.integer :monthly_credit_allowance, null: false, default: 0
      t.integer :credits_used_this_cycle, null: false, default: 0
      t.date :cycle_start
      t.date :cycle_end
      t.integer :avg_daily_burn, default: 0
      t.string :billing_contact
      t.string :enabled_modules, array: true, null: false, default: []

      t.timestamps
    end
    add_index :accounts, :account_id, unique: true
    add_index :accounts, :status
  end
end
