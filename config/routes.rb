Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "dashboard#home"

  post "robinhood_login", to: "robinhood#login"
  get "logout", to: "robinhood#logout"

  get "portfolios", to: "robinhood#portfolios"
  get "positions", to: "robinhood#positions"
  get "quote", to: "robinhood#quote"
  get "transfers", to: "robinhood#transfers"
  get "markets", to: "robinhood#markets"
  get "fundamentals", to: "robinhood#fundamentals"
  get "history", to: "robinhood#history"
  get "movers", to: "robinhood#movers"
  get "news", to: "robinhood#news"

  post "add_to_watchlist", to: "robinhood#add_to_watchlist"
  post "remove_from_watchlist", to: "robinhood#remove_from_watchlist"
  get "watchlist", to: "robinhood#watchlist"

  get "orders", to: "robinhood#orders"
  post "new_order", to: "robinhood#new_order"
  get "cancel_order", to: "robinhood#cancel_order"
end
