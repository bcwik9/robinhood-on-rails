class ApplicationController < ActionController::Base
  include Robinhood
  protect_from_forgery with: :exception

  before_filter :check_for_new_user

  def user_logged_in_to_robinhood?
    @logged_in ||= session[:robinhood_oauth].present? && session[:robinhood_id].present?
  end

  def current_user
    @current_user ||= RobinhoodUser.find_by robinhood_id: session[:robinhood_id] if user_logged_in_to_robinhood?
  end

  def find_or_create_instrument url
    instrument = Instrument.find_by url: url
    if instrument.nil?
      instrument_data =  robinhood_get url
      instrument = Instrument.create!(
                                      name: instrument_data["name"],
                                      url: instrument_data["url"],
                                      quote_url: instrument_data["quote"],
                                      symbol: instrument_data["symbol"],
                                      fundamentals_url: instrument_data["fundamentals"],
                                      robinhood_id: instrument_data["id"]
                                      )
    end
    instrument
  end

  def find_or_create_crypto_pair pair_id
    instrument = Instrument.find_by robinhood_id: pair_id
    if instrument.nil?
      data = get_crypto_pair pair_id
      instrument = Instrument.create!(
                                      name: data["name"],
                                      symbol: data["symbol"],
                                      robinhood_id: data["id"],
                                      url: "#{ROBINHOOD_CRYPTO_URL}/currency_pairs/#{data["id"]}/"
                                      )
    end
    instrument
  end

  private

  def check_for_new_user
    if current_user.nil?
      return unless user_logged_in_to_robinhood?
      get_user
      user = RobinhoodUser.create!(
                                   robinhood_id: @user["id"],
                                   username: @user["username"],
                                   first_name: @user["first_name"],
                                   last_name: @user["last_name"]
                                   )
      
      # load accounts
      get_accounts.each do |a|
        current_user.robinhood_accounts.create! account_number: a["account_number"]
      end
      
      # load portfolio
      get_positions
      instruments = []
      @positions.each do |position|
        instrument = find_or_create_instrument position["instrument"]
        instruments << instrument
      end
      current_user.main_account.stock_lists.create! group: :portfolio, instruments: instruments
      
      # load watchlist
      get_watchlists
      default_watchlist = @watchlists.first
      default_watchlist_data = robinhood_get default_watchlist["url"]
      instruments = []
      get_all_results(default_watchlist_data).each do |stock|
        instrument = find_or_create_instrument stock["instrument"]
        instruments << instrument
      end
      current_user.main_account.stock_lists.create! group: default_watchlist["name"], instruments: instruments

      # load crypto watchlist
      if false
        get_crypto_watchlists
        default_watchlist = @crypto_watchlists.first
        instruments = []
        default_watchlist["currency_pair_ids"].each do |pair_id|
          instrument = find_or_create_crypto_pair pair_id
          instruments << instrument
        end
        current_user.main_account.stock_lists.create! group: "crypto_watchlist_#{default_watchlist["name"]}", instruments: instruments
      end
    end
  end

end
