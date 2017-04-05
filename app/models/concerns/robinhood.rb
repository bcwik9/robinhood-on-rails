module Robinhood
  extend ActiveSupport::Concern

  def get_portfolios
    @portfolios = get_all_results robinhood_get("https://api.robinhood.com/portfolios/")
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

  def get_fundamentals symbols=params["symbols"].split(",")
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

  def price_line_chart
    get_portfolio_history get_accounts.first["account_number"], "10minute", {span: "week"}
    columns = [ {role: :none, data: ['number', 'X']} ] # add x axis

    # each stock has a value and a tooltip
    columns = columns + 
      [
       {role: :none, data: ['number', "Stock1"]},
       {role: :tooltip, data: {type: :string, role: :tooltip}},
      ]

    rows = []
    @portfolio_history["equity_historicals"].each_with_index do |h,i|
      rows[i] ||= [i+1]
      rows[i] = rows[i] + [h["adjusted_close_equity"].to_f, h["begins_at"]]
    end
    
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
      series: {"0": {color: "#21ce99"}},
      backgroundColor: "#090d16"
    }
    
    {columns: columns, rows: rows, options: options}
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
