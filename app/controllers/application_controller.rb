class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def user_logged_in_to_robinhood?
    session[:robinhood_auth_token].present?
  end
end
