class RobinhoodController < ApplicationController

  def login
    response = robinhood_post "https://api.robinhood.com/api-token-auth/", {"username" => params[:username], "password" => params[:password]}
    session[:robinhood_auth_token] = response["token"]
    session[:robinhood_user] = robinhood_get "https://api.robinhood.com/user/"
    session[:robinhood_accounts] = robinhood_get("https://api.robinhood.com/accounts/")["results"]
    redirect_to root_path
  end

  def logout
    reset_session
    redirect_to root_path
  end

  def quote
    @side = params[:side] || "buy"
    begin
      positions if @side =~ /sell/i
      @quotes = robinhood_get("https://api.robinhood.com/quotes/?symbols=#{params["symbols"]}")["results"]
      @quotes.delete_if{|q| q.nil?}
    rescue Exception => e
      @quotes = {}
    end
  end

  def portfolios
    @portfolios = robinhood_get("https://api.robinhood.com/portfolios/")["results"]
  end

  def positions
    @investments = {}
    response = robinhood_get "https://api.robinhood.com/positions/"
    @positions = response["results"]
    # example of pagination to get everything (iterate all pages)
    next_page = response["next"]
    while next_page.present?
      response = robinhood_get "https://api.robinhood.com/positions/"
      @positions += response["results"]
      next_page = response["next"]
    end

    # remove positions where the user has no shares
    @positions.delete_if{|p| p["quantity"].to_f == 0.0}

    @instruments = []
    @positions.each do |position|
      instrument = robinhood_get position["instrument"]
      @instruments << instrument
      @investments[instrument["symbol"]] = position.merge instrument
    end

    @quotes = robinhood_get("https://api.robinhood.com/quotes/?symbols=#{@investments.keys.join(',')}")["results"]
    @quotes.each do |quote|
      @investments[quote["symbol"]].merge! quote
    end

    render layout: false
  end

  def watchlist
    @side = :buy
    @watchlists = robinhood_get("https://api.robinhood.com/watchlists/")["results"]
    default = robinhood_get @watchlists.first["url"]
    @instruments = []
    @investments = {}
    default["results"].each do |instrument|
      instrument_data = robinhood_get instrument["instrument"]
      @instruments << instrument_data
      @investments[instrument_data["symbol"]] = instrument_data
    end

    @quotes = robinhood_get("https://api.robinhood.com/quotes/?symbols=#{@investments.keys.join(',')}")["results"]
    @quotes.each do |quote|
      @investments[quote["symbol"]].merge! quote
    end

    render "quote", layout: false
  end

  def orders
    @orders = robinhood_get("https://api.robinhood.com/orders/")["results"]
    @orders.each do |order|
      order["instrument"] = robinhood_get order["instrument"]
    end
  end

  def new_order
    data = {
      account: session[:robinhood_accounts].first["url"],
      instrument: instrument_from_symbol(params["symbol"])["url"],
      symbol: params["symbol"],
      side: params["side"], # buy|sell
      quantity: params["quantity"],
      price: params["price"].to_f,
      type: "market",
      time_in_force: "gfd",
      trigger: "immediate"
    }

    response = robinhood_post "https://api.robinhood.com/orders/", data
    success = response["id"].present?
    if success
      flash[:success] = "Successfully placed order"
    else
      flash[:warning] = "Failed to place order: #{response.values.join}"
    end

    redirect_to orders_path
  end

  def cancel_order
    response = robinhood_post params["url"], {}
    success = response.empty?
    if success
      flash[:success] = "Successfully canceled order"
    else
      flash[:warning] = "Failed to cancel order: #{response.values.join}"
    end

    redirect_to orders_path
  end

  private

  def robinhood_post url, data
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    headers = {"Accept" => 'application/json'}
    headers["Authorization"] = "Token #{session[:robinhood_auth_token]}" if user_logged_in_to_robinhood?
    request = Net::HTTP::Post.new(uri.request_uri, initheader=headers)
    request.set_form_data(data)
    response = http.request(request)
    JSON.parse(response.body)
  end

  def robinhood_get url
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    headers = {"Accept" => 'application/json'}
    headers["Authorization"] = "Token #{session[:robinhood_auth_token]}" if user_logged_in_to_robinhood?
    request = Net::HTTP::Get.new(uri.request_uri, initheader=headers)
    response = http.request(request)
    JSON.parse(response.body)
  end

  def instrument_from_symbol symbol
    robinhood_get("https://api.robinhood.com/instruments/?symbol=#{symbol}")["results"].first
  end
end
