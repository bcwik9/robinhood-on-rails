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

  def get_orders
    @orders = get_all_results robinhood_get("https://api.robinhood.com/orders/")
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
