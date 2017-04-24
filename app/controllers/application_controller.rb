class ApplicationController < ActionController::Base
  include Robinhood
  protect_from_forgery with: :exception

  def user_logged_in_to_robinhood?
    session[:robinhood_auth_token].present? && session[:robinhood_id].present?
  end

  def current_user
    @current_user ||= RobinhoodUser.find_by robinhood_id: session[:robinhood_id] if user_logged_in_to_robinhood?
  end
end
