class AddImmutabilityTriggerToConsentCertificates < ActiveRecord::Migration[8.0]
  # Rails-level immutability (no update route, no update! anywhere in the
  # app) stops the app from editing a certificate, but nothing stops a raw
  # SQL UPDATE/DELETE run directly against the database. A trigger closes
  # that gap at the one place that can actually enforce it.
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION block_consent_certificate_mutation()
      RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'consent_certificates rows are immutable (attempted % on id=%)', TG_OP, OLD.id;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER consent_certificates_immutable
        BEFORE UPDATE OR DELETE ON consent_certificates
        FOR EACH ROW EXECUTE FUNCTION block_consent_certificate_mutation();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS consent_certificates_immutable ON consent_certificates;
      DROP FUNCTION IF EXISTS block_consent_certificate_mutation();
    SQL
  end
end
