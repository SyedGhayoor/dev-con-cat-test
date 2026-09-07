class CreatePolicyVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :policy_versions do |t|
      t.references :account, foreign_key: true # null == platform default policy
      t.string :name, null: false
      t.integer :version, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.jsonb :config, null: false, default: {}
      # config shape:
      # { "hard_stops" => ["litigator_confirmed", "dnc_listed", "exact_duplicate", "trustedform_mismatch", "trustedform_expired"],
      #   "weights"    => { "signal_code" => weight, ... },
      #   "thresholds" => { "review" => 30, "reject" => 60 } }

      t.timestamps
    end
    add_index :policy_versions, [:account_id, :active]
  end
end
