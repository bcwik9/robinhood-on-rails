class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_filter :check_debug

  def user_logged_in_to_robinhood?
    session[:robinhood_auth_token].present?
  end

  def check_debug
    @debug = true if params[:debug].present?
  end
end
