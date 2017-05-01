module Robinhood
  extend ActiveSupport::Concern

  # colors
  ROBINHOOD_GREEN = "#21ce99"
  ROBINHOOD_ORANGE = "#fc4d2d"

  def set_account_token username, password, security_code=nil
    opts = {"username" => username, "password" => password}
    opts["mfa_code"] = security_code if security_code.present?
    response = robinhood_post "https://api.robinhood.com/api-token-auth/", opts
    if !response["mfa_required"]
      session[:robinhood_auth_token] = response["token"]
      get_user
      session[:robinhood_id] = @user["id"]
    end
    response
  end

  def get_positions
    @positions = get_all_results(robinhood_get "https://api.robinhood.com/positions/?nonzero=true")
  end

  def reorder_portfolio_positions instrument_ids
    robinhood_get("https://api.robinhood.com/positions/?ordering=#{instrument_ids.join ','}")
  end

  def get_portfolios
    @portfolios = get_all_results robinhood_get("https://api.robinhood.com/portfolios/")
  end

  def get_watchlists
    @watchlists = get_all_results robinhood_get("https://api.robinhood.com/watchlists/")
  end

  def reorder_watchlist name, instrument_ids
    robinhood_post("https://api.robinhood.com/watchlists/#{name}/reorder/", {uuids: instrument_ids.join(",")})
  end

  def get_quotes symbols
    @quotes = get_all_results robinhood_get("https://api.robinhood.com/quotes/?symbols=#{symbols.join(',')}")
  end

  def get_dividends
    @dividends = get_all_results robinhood_get "https://api.robinhood.com/dividends/"
  end

  def get_documents
    @documents = get_all_results robinhood_get "https://api.robinhood.com/documents/"
  end

  def get_markets
    @markets = get_all_results robinhood_get("https://api.robinhood.com/markets/")
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
  end

  def get_transfers
    @transfers = get_all_results robinhood_get("https://api.robinhood.com/ach/transfers/")
  end

  def get_news symbol
    @news = robinhood_get "https://api.robinhood.com/midlands/news/#{symbol.upcase}/"
  end

  def get_sp500_movers direction
    @movers = robinhood_get "https://api.robinhood.com/midlands/movers/sp500/?direction=#{direction}"
  end

  # days have a range of  1 to 21, but 21 days is a LOT! typically don't do > 7
  def get_companies_reporting_earnings_within days
    @earnings = robinhood_get("https://api.robinhood.com/marketdata/earnings/?range=#{days}day")["results"]
  end

  def get_earnings symbol
    @earnings = robinhood_get("https://api.robinhood.com/marketdata/earnings/?symbol=#{symbol}")["results"]
  end

  def next_earnings_report symbol
    get_earnings symbol
    @earnings = @earnings.find{|e| DateTime.parse(e["report"]["date"]) >= Time.now}
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
    @history = robinhood_get url
  end

  def get_portfolio_history account, interval, opts={}
    url = "https://api.robinhood.com/portfolios/historicals/#{account}/?interval=#{interval}"
    opts.each do |k,v|
      url += "&#{k}=#{v}"
    end
    @portfolio_history = robinhood_get(url)
  end

  def get_orders
    @orders = get_all_results robinhood_get("https://api.robinhood.com/orders/")
  end

  def get_fundamentals symbols
    @fundamentals ||= {}
    symbols.each_with_index do |symbol,i|
      @fundamentals[symbol.upcase] = robinhood_get("https://api.robinhood.com/fundamentals/?symbols=#{symbol.upcase}")["results"].try(:first)
    end
  end

  def get_cards
    @cards = robinhood_get("https://api.robinhood.com/midlands/notifications/stack/")["results"]
    # show newest first
    now = Time.now.to_s
    @cards.sort!{|a,b| DateTime.parse(b["time"] || now) <=> DateTime.parse(a["time"] || now)}
  end
  
  def dismiss_notification notification_url
    id = notification_url.split('/').last.to_s
    response = robinhood_post "https://api.robinhood.com/midlands/notifications/stack/#{id}/dismiss/", {}
    response.empty?
  end

  def get_user
    @user = robinhood_get "https://api.robinhood.com/user/"
  end

  def get_accounts
    @accounts = robinhood_get("https://api.robinhood.com/accounts/")["results"]
  end

  def create_new_watchlist name
    # this endpoint seemingly doesnt work
    robinhood_post "https://api.robinhood.com/watchlists/", {name: name}
  end

  def portfolio_line_chart interval="5minute", opts={span: "day"}
    get_portfolio_history get_accounts.first["account_number"], interval, opts
    columns = [ {role: :none, data: ['number', 'X']} ] # add x axis

    # each stock has a value and a tooltip
    columns = columns + 
      [
       {role: :none, data: ['number', "Portfolio"]},
       {role: :tooltip, data: {type: :string, role: :tooltip}}
      ]

    rows = []
    @portfolio_history["equity_historicals"].each_with_index do |h,i|
      rows[i] ||= [i+1]
      rows[i] = rows[i] + [h["adjusted_close_equity"].to_f, h["begins_at"]]
    end
    
    open_price = @portfolio_history["equity_historicals"].first["adjusted_open_equity"].to_f
    close_price = @portfolio_history["equity_historicals"].last["adjusted_close_equity"].to_f
    color = close_price > open_price ? ROBINHOOD_GREEN : ROBINHOOD_ORANGE
    options = {
      #title: "Price chart",
      hAxis: {
        #title: 'Date',
        ticks: 'none', #rows.map{ |r| r.first },
        gridlines: {color: "transparent"}
      },
      vAxis: {
        #title: 'Price',
        gridlines: {color: "transparent"}
      },
      focusTarget: :category, # show all tooltips for column on hover,
      #curveType: :function, # curve lines, comment out to disable
      legend: :none,
      chartArea: { width: '90%', height: '75%' },
      series: {"0": {color: color}},
      backgroundColor: "#090d16"
    }
    
    {columns: columns, rows: rows, options: options}
  end

  def stock_line_chart symbol, interval="5minute", opts={span: "day"}
    get_history symbol, interval, opts
    columns = [ {role: :none, data: ['number', 'X']} ] # add x axis

    # each stock has a value and a tooltip
    columns = columns + 
      [
       {role: :none, data: ['number', symbol]},
       {role: :tooltip, data: {type: :string, role: :tooltip}}
      ]

    rows = []
    last_price = 0.0
    @history["historicals"].each_with_index do |h,i|
      rows[i] ||= [i+1]
      rows[i] = rows[i] + [h["close_price"].to_f, h["begins_at"]]
      last_price = h["close_price"].to_f
    end

    color = @history["previous_close_price"].to_f < last_price ? ROBINHOOD_GREEN : ROBINHOOD_ORANGE
    options = {
      #title: "Price chart",
      hAxis: {
        #title: 'Date',
        ticks: 'none', #rows.map{ |r| r.first },
        gridlines: {color: "transparent"}
      },
      vAxis: {
        #title: 'Price',
        gridlines: {color: "transparent"}
      },
      focusTarget: :category, # show all tooltips for column on hover,
      #curveType: :function, # curve lines, comment out to disable
      legend: :none,
      chartArea: { width: '90%', height: '75%' },
      series: {"0": {color: color}},
      backgroundColor: "#090d16"
    }
    
    {columns: columns, rows: rows, options: options}
  end

  def get_price_intersections history
    close_prices = history["historicals"].map{|h| h["close_price"].to_f}
    period_one = 50
    period_two = 200
    periods = [period_one, period_two].sort!
    shorter_sma = simple_moving_average(close_prices, periods.first)
    longer_sma = simple_moving_average(close_prices, periods.last)
    combined = longer_sma.reverse.map.with_index{|longer,i| {shorter_sma: shorter_sma[(i*-1)-1], longer_sma: longer}}
    combined.each_with_index do |data,i|
      data[:current_price] = history["historicals"][(i*-1)-1]["close_price"].to_f
      data[:date] = history["historicals"][(i*-1)-1]["begins_at"]
    end
    combined.reverse!
    prev_change = combined.first[:shorter_sma] / combined.first[:longer_sma] - 1
    combined.each_with_index do |data,i|
      next if i == 0
      change = data[:shorter_sma] / data[:longer_sma] - 1
      if prev_change.negative? && change.positive?
        # upward trend
        data[:action] = :buy
      end
      if prev_change.positive? && change.negative?
        # downward trend
        data[:action] = :sell
      end
      prev_change = change
    end
    raise combined.select{|data| data[:action].present?}.to_s
  end

  def get_instruments query
    @instruments = get_all_results robinhood_get("https://api.robinhood.com/instruments/?query=#{query}")
  end

  def instrument_from_symbol symbol
    robinhood_get("https://api.robinhood.com/instruments/?symbol=#{symbol}")["results"].first
  end

  def get_all_results response, params=""
    results = response["results"]
    next_page = response["next"]
    while next_page.present?
      response = robinhood_get next_page + params
      results += response["results"]
      next_page = response["next"]
    end
    results
  end

  def robinhood_post url, data
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    headers = {"Accept" => 'application/json'}
    headers["Authorization"] = "Token #{session[:robinhood_auth_token]}" if session[:robinhood_auth_token].present?
    request = Net::HTTP::Post.new(uri.request_uri, initheader=robinhood_headers)
    request.set_form_data(data)
    response = http.request(request)
    JSON.parse(response.body)
  end

  def robinhood_delete url
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Delete.new(uri.request_uri, initheader=robinhood_headers)
    response = http.request(request)
  end

  def robinhood_get url
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri, initheader=robinhood_headers)
    response = http.request(request)
    JSON.parse(response.body)
  end

  private

  def robinhood_headers
    headers = {"Accept" => 'application/json'}
    headers["Authorization"] = "Token #{session[:robinhood_auth_token]}" if session[:robinhood_auth_token].present?
    headers
  end
end
