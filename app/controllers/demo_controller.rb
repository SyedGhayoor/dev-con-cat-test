# Serves the assignment's own examples/ files directly so `bin/rails server`
# alone is enough to see the live demo. No second static file server, and
# no duplicated copy of the JS/HTML to drift out of sync with examples/.
class DemoController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized, :verify_policy_scoped
  # This IS a script meant to be <script src>'d from arbitrary third-party
  # landing pages. Rails' cross-origin-<script> CSRF guard exists for the
  # opposite case (protecting authenticated JSON/JS from being read
  # cross-origin) and would otherwise 422 exactly the embedding this file is
  # for.
  skip_forgery_protection only: :pixel_js

  def landing_page
    render file: Rails.root.join("examples", "landing-page.html"), layout: false
  end

  def pixel_js
    send_file Rails.root.join("examples", "super-pixel.js"),
              type: "application/javascript", disposition: "inline"
  end
end
