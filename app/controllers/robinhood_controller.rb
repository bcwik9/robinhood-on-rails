class RobinhoodController < ApplicationController
  
  def login
    response = robinhood_post "https://api.robinhood.com/api-token-auth/", {"username" => params[:username], "password" => params[:password]}
    session[:robinhood_auth_token] = response["token"]
    redirect_to root_path
  end

  def logout
    session.keys.select{|k| k =~ /robinhood/i}.each do |k|
      session.delete k
    end
    redirect_to root_path
  end

  def basic_info
    session[:robinhood_user] ||= robinhood_get "https://api.robinhood.com/user/"
    @basic_info = session[:robinhood_user]
  end

  def quote
    @quotes = robinhood_get("https://api.robinhood.com/quotes/?symbols=#{params["symbols"]}")["results"]
  end

  def portfolios
    @portfolios = robinhood_get("https://api.robinhood.com/portfolios/")["results"]
  end

  def positions
    @investments = {}
    @accounts = []
    response = robinhood_get "https://api.robinhood.com/positions/"
    @positions = response["results"]
    next_page = response["next"]
    while next_page.present?
      response = robinhood_get "https://api.robinhood.com/positions/"
      @positions += response["results"]
      next_page = response["next"]
    end
    @instruments = []
    @positions.each do |position|
      instrument = robinhood_get position["instrument"]
      @instruments << instrument
      @accounts << position["account"] unless @accounts.include?(position["account"])
      @investments[instrument["symbol"]] = position.merge instrument
    end
    @quotes = robinhood_get("https://api.robinhood.com/quotes/?symbols=#{@instruments.map{|i| i["symbol"]}.join(',')}")["results"]
    @quotes.each do |quote|
      @investments[quote["symbol"]].merge! quote
    end
  end

  def orders
    @orders = robinhood_get("https://api.robinhood.com/orders/")["results"]
  end

  def order
    @order = robinhood_get "https://api.robinhood.com/orders/#{params["order_id"]}/"
  end

  def new_order
    data = {
      account: params["account"],
      instrument: params["instrument"],
      symbol: params["symbol"],
      side: params["side"], # buy|sell
      quantity: params["quantity"],
      type: "market",
      time_in_force: "fok",
      trigger: "immediate"      
    }

    @order = robinhood_post "https://api.robinhood.com/orders/", data
    render 
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
end
