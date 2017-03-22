class RobinhoodController < ApplicationController

  def login
    response = robinhood_post "https://api.robinhood.com/api-token-auth/", {"username" => params[:username], "password" => params[:password]}
    session[:robinhood_auth_token] = response["token"]
    session[:robinhood_user] = robinhood_get "https://api.robinhood.com/user/"
    refresh_accounts
    redirect_to root_path
  end

  def logout
    reset_session
    redirect_to root_path
  end

  def markets
    @markets = robinhood_get("https://api.robinhood.com/markets/")["results"]
    @markets.delete_if{|m| m["mic"] !~ /(xnys|xnas)/i }
    @markets.each do |market|
      market.merge! robinhood_get(market["todays_hours"])
      if !market["opens_at"]
        next_open = robinhood_get(market["next_open_hours"])
        market["opens_at"] = next_open["opens_at"]
        market["closes_at"] = next_open["closes_at"]
      else
        closes = DateTime.parse market["closes_at"]
        if closes < Time.now
          next_open = robinhood_get(market["next_open_hours"])
          market["opens_at"] = next_open["opens_at"]
          market["closes_at"] = next_open["closes_at"]
        end
      end
    end
    render layout: false
  end

  def fundamentals
    get_fundamentals
    render layout: false
  end
  
  def movers
    if params[:direction].present?
      @movers = get_sp500_movers(params[:direction])["results"]
    else
      @up_and_down = get_sp500_movers("up")["results"]
      @up_and_down += get_sp500_movers("down")["results"]
      @movers = @up_and_down
    end
    render layout: false
  end

  def news
    get_news params[:symbol]
  end

  def history
    get_history params[:symbol].upcase, params[:interval].downcase, {span: params[:span].downcase}
    render layout: false
  end

  def quote
    @side = params[:side] || "buy"
    begin
      if @side =~ /buy/i
        refresh_accounts
      else
        positions
      end
      quote_url = "https://api.robinhood.com/quotes/?symbols="
      @quotes = robinhood_get(quote_url + params["symbols"].upcase)["results"]
      @quotes.delete_if{|q| q.nil?}
    rescue Exception => e
      if(!@quotes || @quotes.empty?)
        instruments = robinhood_get("https://api.robinhood.com/instruments/?query=#{params["symbols"].upcase}")["results"]
        @quotes = instruments.map{|instrument| robinhood_get instrument["quote"]}
      end
    ensure
      @quotes ||= {}
    end
  end

  def transfers
    @transfers = robinhood_get("https://api.robinhood.com/ach/transfers/")["results"]
  end

  def portfolios
    refresh_accounts
    @portfolios = robinhood_get("https://api.robinhood.com/portfolios/")["results"]
    render layout: false
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
    default_watchlist = robinhood_get @watchlists.first["url"]
    @instruments = []
    @investments = {}
    default_watchlist["results"].each do |instrument|
      instrument_data = robinhood_get instrument["instrument"]
      @instruments << instrument_data
      @investments[instrument_data["symbol"]] = instrument_data
    end

    @quotes = robinhood_get("https://api.robinhood.com/quotes/?symbols=#{@investments.keys.join(',')}")["results"]
    @quotes.each do |quote|
      @investments[quote["symbol"]].merge! quote
    end

    refresh_accounts

    render "quote", layout: false
  end

  def add_to_watchlist
    response = robinhood_post("https://api.robinhood.com/watchlists/Default/bulk_add/", {symbols: params["symbols"]})
    if response.present?
      flash[:success] = "Added position to watchlist."
      redirect_to root_path
    else
      flash[:warning] = "Position already on watchlist."
      redirect_to request.referrer
    end
  end

  def remove_from_watchlist
    instrument = instrument_from_symbol params["symbol"]
    response = robinhood_delete "https://api.robinhood.com/watchlists/Default/#{instrument["id"]}/"
    flash[:success] = "Removed #{params["symbol"]} from watchlist."
    redirect_to root_path
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
      flash[:success] = "Successfully placed order."
    else
      flash[:warning] = "Failed to place order: #{response.values.join}."
    end

    redirect_to orders_path
  end

  def cancel_order
    response = robinhood_post params["url"], {}
    success = response.empty?
    if success
      flash[:success] = "Successfully canceled order."
    else
      flash[:warning] = "Failed to cancel order: #{response.values.join}."
    end

    redirect_to orders_path
  end

  private

  def get_news symbol
    @news = robinhood_get "https://api.robinhood.com/midlands/news/#{symbol.upcase}/"
  end

  def get_sp500_movers direction
    @movers = robinhood_get "https://api.robinhood.com/midlands/movers/sp500/?direction=#{direction}"
  end

  # GET /quotes/historicals/$symbol/[?interval=$i&span=$s&bounds=$b] interval=week|day|10minute|5minute|null(all) span=day|week|year|5year|all bounds=extended|regular|trading
  # only certain combos work, such as:
  # get_history :AAPL, "5minute", {span: "day"}
  # get_history :AAPL, "10minute", {span: "week"}
  # get_history :AAPL, "day", {span: "year"}
  # get_history :AAPL, "week", {span: "5year"}
  def get_history symbol, interval, opts={}
    url = "https://api.robinhood.com/quotes/historicals/#{symbol}/?interval=#{interval}"
    opts.each do |k,v|
      url += "&#{k}=#{v}"
    end
    @history = robinhood_get(url)["historicals"]
  end

  def get_fundamentals symbols=params["symbols"].split(",")
    @fundamentals ||= {}
    symbols.each_with_index do |symbol,i|
      @fundamentals[symbol.upcase] = robinhood_get("https://api.robinhood.com/fundamentals/?symbols=#{symbol.upcase}")["results"].try(:first)
    end
  end

  def refresh_accounts
    session[:robinhood_accounts] = robinhood_get("https://api.robinhood.com/accounts/")["results"]
  end

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

  def robinhood_delete url
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    headers = {"Accept" => 'application/json'}
    headers["Authorization"] = "Token #{session[:robinhood_auth_token]}" if user_logged_in_to_robinhood?
    request = Net::HTTP::Delete.new(uri.request_uri, initheader=headers)
    response = http.request(request)
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
