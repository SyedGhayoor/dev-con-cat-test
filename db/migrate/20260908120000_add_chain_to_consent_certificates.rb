class AddChainToConsentCertificates < ActiveRecord::Migration[8.0]
  def change
    add_column :consent_certificates, :previous_hash, :string
    # No default on purpose: every certificate is created through
    # ConsentCertificate#assign_chain_position, which always sets this
    # explicitly, the same way certificate_uid has no default either.
    add_column :consent_certificates, :sequence_number, :integer, null: false

    # One chain per account: certificate #1, #2, #3... in issuance order, so
    # a deleted or reordered certificate breaks the chain visibly instead of
    # just quietly disappearing.
    add_index :consent_certificates, [:account_id, :sequence_number], unique: true
  end
end
