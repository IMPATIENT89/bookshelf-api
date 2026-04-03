Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    resources :authors, only: [ :index, :show, :create, :update, :destroy ] do
      get :books, on: :member
    end
  end
end
