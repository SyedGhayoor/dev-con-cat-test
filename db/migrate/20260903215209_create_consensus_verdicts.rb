class CreateConsensusVerdicts < ActiveRecord::Migration[8.0]
  def change
    create_table :consensus_verdicts do |t|
      t.references :verification_run, null: false, foreign_key: true, index: { unique: true }
      t.references :account, null: false, foreign_key: true
      t.references :policy_version, null: false, foreign_key: true
      t.string :verdict, null: false # accept | review | reject
      t.float :score
      t.jsonb :reasons, null: false, default: [] # [{code, layer, weight, human_text}, ...]

      t.timestamps
    end
    add_index :consensus_verdicts, [:account_id, :verdict]
  end
end
