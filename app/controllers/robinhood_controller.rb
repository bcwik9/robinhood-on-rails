class RobinhoodController < ApplicationController
  include Robinhood
  include FinanceCalculator

  def login
    response = set_account_token params[:username], params[:password], params[:security_code]

    flash[:info] = "Please provide the security code that was sent via text." if response["mfa_required"]
    flash[:warning] = response["non_field_errors"].join if response["non_field_errors"].present?
    redirect_to root_path(mfa_required: response["mfa_required"])
  end

  def logout
    reset_session
    @current_user = nil
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
    get_fundamentals params["symbols"].split(",")
    @fundamentals.each do |symbol,data|
      data["earnings"] = next_earnings_report symbol
    end
    render layout: false
  end

  def price_chart
    if params[:type] =~ /portfolio/i
      @chart_data = portfolio_line_chart params[:interval], {span: params[:span]}
    elsif params[:type] =~ /stock/i
      @chart_data = stock_line_chart params[:symbol], params[:interval], {span: params[:span]}
    end
    render layout: false
  end
  
  def movers
    if params[:direction].present?
      @movers = get_sp500_movers(params[:direction])["results"]
    else
      @movers = get_sp500_movers("up")["results"]
      @movers += get_sp500_movers("down")["results"]
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
    redirect_to root_path
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
          get_accounts
        else
          positions
        end
        get_quotes params["symbols"].upcase
        @quotes.delete_if{|q| q.nil?}
      rescue Exception => e
        if(!@quotes || @quotes.empty?)
          get_instruments params["symbols"].upcase
          @quotes = @instruments.map{|instrument| robinhood_get instrument["quote"]}
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
    get_accounts
    get_markets
    get_portfolios

    market = @markets.first
    @market_open = DateTime.parse(market["opens_at"]) if market["opens_at"].present?
    @market_open = @market_open && @market_open < Time.now && DateTime.parse(market["closes_at"]) > Time.now

    render layout: false
  end

  def portfolio_history
    account = current_user.main_account.account_number
    response = get_portfolio_history account, params[:interval], {span: params[:span]}
    raise response.to_s
  end

  def positions
    @investments = {}
    @instruments = []
    get_positions
    @positions.each do |position|
      instrument = find_or_create_instrument position["instrument"]
      @instruments << instrument
      position["instrument"] = instrument
      @investments[instrument["symbol"]] = position
    end

    get_quotes @investments.keys
    @quotes.each do |quote|
      @investments[quote["symbol"]].merge! quote
    end

    get_orders
    @investments.each do |symbol,data|
      data["all_time_return"] =  0.0 # return including sold shares
      data["value"] = 0.0
      data["purchase_cost"] = 0.0
      data["todays_return"] = 0.0
      data["current_price"] = (data["last_extended_hours_trade_price"] || data["last_trade_price"]).to_f
      instrument_orders = @orders.select{|o| o["instrument"] == data["instrument"] && !o["executions"].empty?}
      buy_orders = instrument_orders.select{|o| o["side"] =~ /buy/i}.reverse
      sell_orders = instrument_orders - buy_orders
      total_num_shares_to_skip = sell_orders.map{|o| o["executions"].map{|e| e["quantity"].to_i}.sum }.sum
      data["quantity"] = buy_orders.map{|o| o["executions"].map{|e| e["quantity"].to_i}.sum}.sum - total_num_shares_to_skip
      data["value"] = data["quantity"].to_i * data["current_price"]
      buy_orders.each do |o|
        purchase_price = (o["average_price"] || o["price"]).to_f
        purchase_quantity = o["executions"].map{|e| e["quantity"].to_i}.sum
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
      data["amount_sold"] = sell_orders.map{|o| o["executions"].map{|e| e["quantity"].to_i}.sum * (o["average_price"] || o["price"]).to_f - o["fees"].to_f}.sum
      data["shares_held_cost"] = data["average_buy_price"].to_f * data["quantity"]
      data["shares_held_return"] = data["value"] - data["shares_held_cost"]
      data["all_time_return"] = data["value"] - data["purchase_cost"] + data["amount_sold"]
    end

    # remove investments where we no longer hold any shares
    @investments.delete_if{|symbol,data| data["quantity"].to_i <= 0}

    @stock_lists = current_user.update_stock_list :portfolio, @instruments
    @stock_lists = @stock_lists.sort{|a,b| a.name.nil? ? 0 : 1}
    
    render layout: false
  end

  def delete_stock_list
    current_user.stock_lists.find(params[:id]).try(:delete)
    render nothing: true
  end

  def add_stock_list
    current_user.main_account.stock_lists.create! group: params[:group], name: params[:name]
    flash[:success] = "Added section."
    redirect_to root_path
  end

  def reorder_positions
    instrument_order = Instrument.find(params[:instrument_order])
    list = current_user.stock_lists.find params[:id]
    if list.present?
      robinhood_instruments = Instrument.find(params[:robinhood_order]).pluck(:robinhood_id)
      reorder_portfolio_positions robinhood_instruments  if list.group == "portfolio"
      reorder_watchlist :Default, robinhood_instruments  if list.group == "watchlist"
      instrument = Instrument.find params[:instrument_id]
      group_lists = current_user.stock_lists.where(group: list.group)
      group_lists.each do |l|
        l.instruments.delete instrument if l.instruments.include? instrument
      end
      list.instruments.clear
      list.update! instruments: instrument_order
    end
    
    render nothing: true
  end

  def create_watchlist
    # This endpoint doesnt work
    response = create_new_watchlist params[:name]
    flash[:success] = response.to_s
    redirect_to root_path
  end

  def watchlist
    @side = :buy
    get_watchlists
    default_watchlist = robinhood_get @watchlists.first["url"]
    @instruments = []
    @investments = {}
    get_all_results(default_watchlist).each do |stock|
      instrument = find_or_create_instrument stock["instrument"]
      @instruments << instrument
      @investments[instrument.symbol] = {instrument: instrument}
    end

    @quotes = get_quotes @investments.keys
    @quotes.each do |quote|
      @investments[quote["symbol"]].merge! quote
    end

    get_accounts

    @stock_lists = current_user.update_stock_list :watchlist, @instruments
    @stock_lists = @stock_lists.sort{|a,b| a.name.nil? ? 0 : 1}

    render layout: false
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
      order["filled_quantity"] = order["executions"].map{|e| e["quantity"].to_i}.sum.to_s
    end
  end

  def new_order
    get_accounts
    data = {
      account: @accounts.first["url"],
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
