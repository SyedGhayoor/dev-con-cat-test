class CreateLayerResults < ActiveRecord::Migration[8.0]
  def change
    create_table :layer_results do |t|
      t.references :verification_run, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :layer, null: false
      # state is the three(+one)-way distinction the assignment calls out explicitly:
      #   not_enabled | not_applicable | returned_verdict | skipped_insufficient_credits
      t.string :state, null: false
      t.jsonb :raw_response, null: false, default: {}
      t.integer :credits_charged, null: false, default: 0
      t.datetime :evaluated_at

      t.timestamps
    end
    add_index :layer_results, [:verification_run_id, :layer], unique: true
    add_index :layer_results, [:account_id, :layer]
  end
end
