module Api
  # Base for the public, unauthenticated pixel endpoints. Deliberately does
  # NOT include the Authentication/Pundit stack from ApplicationController.
  # there is no logged-in user here, just an anonymous site visitor's browser.
  class BaseController < ActionController::Base
    skip_forgery_protection

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: :render_missing_param

    private

    def render_not_found
      render json: { error: "not_found" }, status: :not_found
    end

    def render_missing_param(exception)
      render json: { error: exception.message }, status: :unprocessable_entity
    end
  end
end
