Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "dashboard#show"

  get "/demo", to: "demo#landing_page"
  get "/super-pixel.js", to: "demo#pixel_js"

  resources :pixels
  resources :leads, only: [:index, :show]
  resources :certificates, only: [:show], param: :certificate_uid do
    member do
      get :verify # public, no-PII tamper-evidence check
    end
  end

  namespace :admin do
    root to: "dashboard#show"
    resources :accounts, only: [:index, :show]
  end

  namespace :api do
    namespace :pixel do
      post :visit, to: "ingestion#visit"
      post :leads, to: "ingestion#create_lead"
      get "leads/:lead_id/activity", to: "activity#stream", as: :lead_activity
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
