class CertificatesController < ApplicationController
  # /verify is the public, no-login link a buyer could hand to a third party
  # (e.g. opposing counsel) to independently confirm a certificate hasn't
  # been altered. It deliberately exposes no PII, just the verdict and a
  # hash-match result.
  allow_unauthenticated_access only: :verify
  skip_after_action :verify_authorized, :verify_policy_scoped, only: :verify

  def show
    @certificate = authorize current_account.consent_certificates.find_by!(certificate_uid: params[:certificate_uid])
  end

  def verify
    # No tenant context exists here. The certificate_uid is its own
    # capability token, so this is a deliberate unscoped lookup.
    @certificate = ConsentCertificate.unscoped.find_by!(certificate_uid: params[:certificate_uid])
  end
end
