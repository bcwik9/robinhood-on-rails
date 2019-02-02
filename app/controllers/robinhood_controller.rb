class RobinhoodController < ApplicationController
  include Robinhood
  include FinanceCalculator

  #before_filter :set_oauth_token, except: [:login, :logout]

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
    crypto_quote
  end

  def crypto_quote
    if params["symbols"].present?
      @side = params[:side] || "buy"
      if @side =~ /buy/i
        pairs = []
        get_crypto_pairs.each do |pair|
          asset_currency = pair["asset_currency"]
          if asset_currency["code"] =~ /#{params["symbols"]}/i || asset_currency["name"] =~ /#{params["symbols"]}/i
            pairs << pair
          end
        end
        @crypto_quotes = get_crypto_pair_quotes(pairs.map{|p| p["id"]}) || []
        @crypto_quotes.each do |quote|
          quote["pair"] = pairs.find{|pair| pair["id"] == quote["id"] }
        end
      end
    end
  end

  def transfers
    get_transfers
    get_ach_accounts
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
      flash[:warning] = "Failed to cancel transfer: #{response.values.join}"
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
    # instant accounts use margin_balances. cash just uses buying power
    @buying_power = @accounts.map{|a| a["margin_balances"].present? ? a["margin_balances"]["overnight_buying_power"] : a["buying_power"]}.sum

    render layout: false
  end

  def portfolio_history
    account = current_user.main_account.account_number
    get_portfolio_history account, params[:interval], {span: params[:span]}
    raise @portfolio_history.to_s
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
      quote.delete "instrument" # we already have it
      @investments[quote["symbol"]].merge! quote
    end

    get_orders
    @investments.each do |symbol,data|
      data["all_time_return"] =  0.0 # return including sold shares
      data["purchase_cost"] = 0.0
      data["amount_sold"] = 0.0
      data["todays_return"] = 0.0
      data["current_price"] = (data["last_extended_hours_trade_price"] || data["last_trade_price"]).to_f
      instrument_orders = @orders.select{|o| o["instrument"] == data["instrument"].url && !o["executions"].empty?}
      buy_orders = instrument_orders.select{|o| o["side"] =~ /buy/i}
      sell_orders = instrument_orders - buy_orders
      total_num_shares_to_skip = sell_orders.map{|o| o["executions"].map{|e| e["quantity"].to_i}.sum }.sum

      get_splits data["instrument"].robinhood_id
      @splits.each{|split| split["updated_at"] = split["execution_date"]}
      current_shares_owned = 0
      # process orders oldest to newest
      orders_and_splits = (instrument_orders + @splits).sort{|a,b| DateTime.parse(a["updated_at"]) <=> DateTime.parse(b["updated_at"])}
      orders_and_splits.each do |o|
        if o["url"] =~ /order/i
          price = (o["average_price"] || o["price"]).to_f
          quantity = o["executions"].map{|e| e["quantity"].to_i}.sum
          if o["side"] =~ /buy/i
            data["purchase_cost"] += price * quantity
            current_shares_owned += quantity
          else
            data["amount_sold"] += (price * quantity - o["fees"].to_f)
            current_shares_owned -= quantity
          end
        else 
          # split
          current_shares_owned = (current_shares_owned / o["divisor"].to_f * o["multiplier"].to_f).to_i
        end
      end
      # TODO: this quantity override doesnt seem to work for stocks received for free (like through the referral program)
      #data["quantity"] = current_shares_owned # override quantity from robinhood

      # calculate todays return (basically check if anything was bought today)
      todays_buy_orders = buy_orders.select{|o| o["executions"].any?{|e| DateTime.parse(e["timestamp"]) > Date.today}}
      todays_buy_orders.each do |o|
        price = (o["average_price"] || o["price"]).to_f
        o["executions"].each do |e|
          executed_shares = e["quantity"].to_i
          current_shares_owned -= executed_shares
          # check if user bought some shares then sold them
          # example: buy 2 shares, sell 1 share in same day
          executed_shares += current_shares_owned if current_shares_owned < 0
          data["todays_return"] += (data["current_price"] - price) * executed_shares
        end
      end
      data["todays_return"] += (data["current_price"] - data["previous_close"].to_f) * current_shares_owned if current_shares_owned > 0

      data["value"] = data["quantity"].to_i * data["current_price"]
      data["shares_held_cost"] = data["average_buy_price"].to_f * data["quantity"].to_i
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
      if list.group =~ /crypto_watchlist_(.+)/i
        name = list.name || $1
        get_crypto_watchlists
        crypto_list = @crypto_watchlists.find{|l| l["name"] == name}
        response = set_crypto_watchlist crypto_list["id"], instrument_order.pluck(:robinhood_id)
      elsif list.group == "portfolio"
        reorder_portfolio_positions robinhood_instruments
      else
        reorder_watchlist list.group, robinhood_instruments
      end
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
    default_watchlist = @watchlists.first
    default_watchlist_data = robinhood_get default_watchlist["url"]
    @instruments = []
    @investments = {}
    get_all_results(default_watchlist_data).each do |stock|
      instrument = find_or_create_instrument stock["instrument"]
      @instruments << instrument
      @investments[instrument.symbol] = {instrument: instrument}
    end

    get_quotes @investments.keys
    @quotes.each do |quote|
      next if quote.blank?
      @investments[quote["symbol"]].merge! quote
    end

    get_accounts

    @stock_lists = current_user.update_stock_list default_watchlist["name"], @instruments
    @stock_lists = @stock_lists.sort{|a,b| a.name.nil? ? 0 : 1}

    render layout: false
  end

  def add_to_watchlist
    if params[:type].present? && params[:type] =~ /crypto/i
      get_crypto_watchlists
      watchlist = @crypto_watchlists.first
      response = set_crypto_watchlist watchlist["id"], (watchlist["currency_pair_ids"] << params[:robinhood_id])
    else
      response = add_symbols_to "Default", [params["symbols"]]
    end
    if response.present?
      flash[:success] = "Added position to watchlist."
      redirect_to root_path
    else
      flash[:warning] = "Position already on watchlist."
      redirect_to request.referrer
    end
  end

  def remove_from_watchlist
    stock_list = current_user.stock_lists.find params[:watchlist_id]
    instrument = instrument_from_symbol params["symbol"]
    if stock_list.cryptocurrency_list?
      get_crypto_watchlists
      watchlist = @crypto_watchlists.find{|list| list["name"] == stock_list.crypto_group }
      response = set_crypto_watchlist watchlist["id"], watchlist["currency_pair_ids"].select{|id| id != params["robinhood_id"]}
    else
      response = remove_symbol_from stock_list.group, instrument["id"]
    end
    flash[:success] = "Removed #{params["symbol"]} from watchlist."
    redirect_to root_path
  end
  
  def crypto_watchlist
    @side = :buy
    get_crypto_watchlists
    @watchlist = @crypto_watchlists.first

    @instruments = []
    #@investments = {}
    @watchlist['currency_pair_ids'].each do |pair_id|
      instrument = find_or_create_crypto_pair pair_id
      @instruments << instrument
      #@investments[instrument.symbol] = {instrument: instrument}
    end
    get_crypto_pair_quotes @watchlist['currency_pair_ids']

    get_accounts

    @stock_lists = current_user.update_stock_list "crypto_watchlist_#{@watchlist['name']}", @instruments
    @stock_lists = @stock_lists.sort{|a,b| a.name.nil? ? 0 : 1}

    render layout: false    
  end

  def orders
    get_orders
    @orders.each do |order|
      order["instrument"] = robinhood_get order["instrument"]
      order["filled_quantity"] = order["executions"].map{|e| e["quantity"].to_i}.sum.to_s
    end
  end

  def new_order
    type = params["type"] =~ /limit/i ? "limit" : "market"
    trigger = params["type"] =~ /stop/i ? "stop" : "immediate"
    data = {
      account: current_user.main_account.url,
      instrument: instrument_from_symbol(params["symbol"])["url"],
      symbol: params["symbol"],
      side: params["side"], # buy|sell
      quantity: params["quantity"],
      type: type,
      time_in_force: params["time_in_force"],
      trigger: trigger
    }
    data[:stop_price] = params["stop_price"].to_f if trigger == "stop"
    data[:price] = params["price"].to_f if type == "limit" || params["side"] == "buy"
    data[:price] = params["stop_price"].to_f if params["side"] == "buy" && params["type"] =~ /stop loss/i

    response = place_order data
    success = response["id"].present?
    if success
      flash[:success] = "Successfully placed order."
      redirect_to orders_path
    else
      flash[:warning] = "Failed to place order: #{response.values.join}"
      redirect_to request.referrer
    end
  end

  def cancel_order
    response = robinhood_post params["url"], {}
    success = response.empty?
    if success
      flash[:success] = "Successfully canceled order."
    else
      flash[:warning] = "Failed to cancel order: #{response.values.join}"
    end

    redirect_to orders_path
  end

  def api
    @url = params["url"] || 'https://api.robinhood.com/'
    get_user unless params["url"].present?
    @data = robinhood_get @url
  end

  def experiments
    get_experiments
  end
end
