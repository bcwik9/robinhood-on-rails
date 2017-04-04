class RobinhoodController < ApplicationController
  include Robinhood

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
    get_markets
    render layout: false
  end

  def dividends
    get_dividends
    @dividends.each do |dividend|
      dividend["instrument"] = robinhood_get dividend["instrument"]
    end
  end

  def documents
    get_documents
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

  def cards
    get_cards
  end

  def dismiss_card
    success = dismiss_notification params["card_url"]
    if success
      flash[:success] = "Dismissed notification."
    else
      flash[:warning] = "Failed to dismiss notification."
    end
    redirect_to cards_path
  end

  def dismiss_all_cards
    get_cards
    success = true
    @cards.each do |card|
      success = success && dismiss_notification(card["url"])
    end
    if success
      flash[:success] = "Dismissed all notifications."
    else
      flash[:warning] = "Failed to dismiss notifications."
    end
    redirect_to cards_path
  end

  def news
    get_news params[:symbol]
  end

  def history
    get_history params[:symbol].upcase, params[:interval].downcase, {span: params[:span].downcase}
    render layout: false
  end

  def quote
    if params["symbols"].present?
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
    else
      @quotes = {}
    end
  end

  def transfers
    get_transfers
    @ach_accounts = robinhood_get("https://api.robinhood.com/ach/relationships/")["results"]
  end

  def new_transfer
    response = robinhood_post "https://api.robinhood.com/ach/transfers/", {direction: params[:direction].downcase, amount: params[:amount], ach_relationship: params[:ach_relationship]}
    success = response["id"].present?
    if success
      flash[:success] = "Successfully created transfer."
    else
      flash[:warning] = response.values.join
    end
    redirect_to transfers_path
  end

  def cancel_transfer
    response = robinhood_post params["transfer_url"], {}
    success = response.empty?
    if success
      flash[:success] = "Successfully canceled transfer."
    else
      flash[:warning] = "Failed to cancel transfer: #{response.values.join}."
    end

    redirect_to transfers_path
  end

  def portfolios
    refresh_accounts
    get_portfolios
    render layout: false
  end

  def portfolio_history
    refresh_accounts
    account = session[:robinhood_accounts].first["account_number"]
    response = robinhood_get "https://api.robinhood.com/portfolios/historicals/#{account}/?span=year&interval=day"
    raise response.to_s
  end

  def positions
    @investments = {}
    response = robinhood_get "https://api.robinhood.com/positions/?nonzero=true"
    @positions = get_all_results response

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

    get_orders
    @investments.each do |symbol,data|
      data["overall_return"] =  0.0
      data["value"] = 0.0
      data["purchase_cost"] = 0.0
      data["todays_return"] = 0.0
      data["current_price"] = (data["last_extended_hours_trade_price"] || data["last_trade_price"]).to_f
      filled_orders = @orders.select{|o| o["state"] !~ /cancelled/i && o["instrument"] == data["instrument"]}
      buy_orders = filled_orders.select{|o| o["side"] =~ /buy/i}.sort{|a,b| a["average_price"].to_f <=> b["average_price"].to_f}
      sell_orders = filled_orders - buy_orders
      total_num_shares_to_skip = sell_orders.map{|o| o["quantity"].to_i}.sum
      data["quantity"] = buy_orders.map{|o| o["quantity"].to_i}.sum - total_num_shares_to_skip
      data["value"] = data["quantity"].to_i * data["current_price"]
      buy_orders.each do |o|
        purchase_price = (o["average_price"] || o["price"]).to_f
        purchase_quantity = o["quantity"].to_i
        data["purchase_cost"] += purchase_price * purchase_quantity

        # factor in if the user has sold some of the purchased shares
        num_shares_to_skip = [purchase_quantity, total_num_shares_to_skip].min
        purchase_quantity -= num_shares_to_skip
        total_num_shares_to_skip -= num_shares_to_skip
        next if purchase_quantity <= 0

        purchased_today = DateTime.parse(o["created_at"]) > Date.today
        compare_price = purchased_today ? purchase_price : data["previous_close"].to_f
        data["todays_return"] += (data["current_price"] - compare_price) * purchase_quantity
      end
      data["amount_sold"] = sell_orders.map{|o|o["quantity"].to_i * (o["average_price"] || o["price"]).to_f}.sum
      data["overall_return"] = data["value"] - data["purchase_cost"] + data["amount_sold"]
    end

    # remove investments where we no longer hold any shares
    @investments.delete_if{|symbol,data| data["quantity"].to_i <= 0}

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
    get_orders
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
end
