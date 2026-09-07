class CreateVerificationRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :verification_runs do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :policy_version, null: false, foreign_key: true
      t.string :status, null: false, default: "pending" # pending | running | completed | aborted
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
    add_index :verification_runs, [:account_id, :created_at]
  end
end
