class CreateActivityEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :lead, foreign_key: true
      t.references :verification_run, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :activity_events, [:account_id, :occurred_at]
    add_index :activity_events, [:lead_id, :occurred_at]
  end
end
