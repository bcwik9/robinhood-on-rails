Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "dashboard#home"

  post "robinhood_login", to: "robinhood#login"
  get "logout", to: "robinhood#logout"

  get "portfolios", to: "robinhood#portfolios"
  get "positions", to: "robinhood#positions"
  get "quote", to: "robinhood#quote"

  get "orders", to: "robinhood#orders"
  post "new_order", to: "robinhood#new_order"
end
