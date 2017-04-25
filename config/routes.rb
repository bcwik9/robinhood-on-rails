Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "dashboard#home"

  post "robinhood_login", to: "robinhood#login"
  get "logout", to: "robinhood#logout"

  get "portfolios", to: "robinhood#portfolios"
  get "portfolio_history", to: "robinhood#portfolio_history"
  get "quote", to: "robinhood#quote"
  get "markets", to: "robinhood#markets"
  get "fundamentals", to: "robinhood#fundamentals"
  get "history", to: "robinhood#history"
  get "movers", to: "robinhood#movers"
  get "news", to: "robinhood#news"
  get "dividends", to: "robinhood#dividends"
  get "documents", to: "robinhood#documents"
  get "price_chart", to: "robinhood#price_chart"

  get "positions", to: "robinhood#positions"
  post "reorder_positions", to: "robinhood#reorder_positions"

  get "transfers", to: "robinhood#transfers"
  post "new_transfer", to: "robinhood#new_transfer"
  get "cancel_transfer", to: "robinhood#cancel_transfer"

  get "cards", to: "robinhood#cards"
  get "dismiss_card", to: "robinhood#dismiss_card"
  get "dismiss_all_cards", to: "robinhood#dismiss_all_cards"

  post "add_to_watchlist", to: "robinhood#add_to_watchlist"
  post "remove_from_watchlist", to: "robinhood#remove_from_watchlist"
  post "create_watchlist", to: "robinhood#create_watchlist"
  get "watchlist", to: "robinhood#watchlist"

  get "orders", to: "robinhood#orders"
  post "new_order", to: "robinhood#new_order"
  get "cancel_order", to: "robinhood#cancel_order"
end
