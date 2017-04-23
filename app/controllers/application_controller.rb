class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def user_logged_in_to_robinhood?
    session[:robinhood_auth_token].present?
  end

  def current_user
    @current_user ||= RobinhoodUser.find session[:current_user] if user_logged_in_to_robinhood?
  end
end
