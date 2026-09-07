class CreateCaptureSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :capture_sessions do |t|
      t.references :pixel, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :session_id, null: false # public token minted by the pixel JS
      t.string :page_url
      t.string :referrer
      t.string :user_agent
      t.string :visit_ip
      t.datetime :started_at, null: false

      t.timestamps
    end
    add_index :capture_sessions, :session_id, unique: true
    add_index :capture_sessions, [:account_id, :created_at]
  end
end
