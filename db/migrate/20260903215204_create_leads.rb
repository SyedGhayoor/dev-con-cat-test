class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pixel, null: false, foreign_key: true
      t.references :capture_session, foreign_key: true
      t.string :lead_id, null: false # public identifier, e.g. "L-1001" or "L-" + token
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone
      t.string :submit_ip
      t.string :landing_page_url
      t.string :campaign
      t.string :trusted_form_cert_url
      t.integer :form_dwell_ms
      t.datetime :submitted_at, null: false
      t.jsonb :raw_fields, null: false, default: {}
      t.string :activity_token # capability token gating the SSE stream, not the lead_id itself
      t.datetime :activity_token_expires_at

      t.timestamps
    end
    add_index :leads, :lead_id, unique: true
    add_index :leads, :activity_token, unique: true
    add_index :leads, [:account_id, :created_at]
    add_index :leads, [:account_id, :phone]
    add_index :leads, [:account_id, :email]
  end
end
