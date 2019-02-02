class DashboardController < ApplicationController
  def home
    if params[:mfa_required].blank? && @current_user.blank?
      # user just starting to log in, reset everything
      reset_session
    end
  end
end
