class CreateConsentCertificates < ActiveRecord::Migration[8.0]
  def change
    create_table :consent_certificates do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :verification_run, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :certificate_uid, null: false # public token used in the verify URL
      t.string :content_hash, null: false # SHA-256 over `snapshot`
      t.string :trusted_form_cert_url
      t.datetime :issued_at, null: false
      t.jsonb :snapshot, null: false, default: {} # frozen copy of layer results + verdict at issuance

      t.timestamps
    end
    add_index :consent_certificates, :certificate_uid, unique: true
    add_index :consent_certificates, [:account_id, :issued_at]
  end
end
