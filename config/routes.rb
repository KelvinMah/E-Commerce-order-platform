Rails.application.routes.draw do
  get "/api/health", to: "health#show"
  namespace :api do
    resources :products, only: %i[index show]
    resources :orders, only: %i[create show]
    post "orders/:id/cancel", to: "orders#cancel"
  end
end
