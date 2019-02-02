module ApplicationHelper
  def user_timezone
    # TODO make this a setting?
    'Eastern Time (US & Canada)'
  end

  def user_logged_in_to_robinhood?
    session[:robinhood_oauth].present? && session[:robinhood_id].present?
  end
  
  def price_display amount
    "$#{set_num_decimals amount}".sub("$-", "-$")
  end

  def up_down start_amount, end_amount
    change_display(start_amount, end_amount).include?('+') ? "success" : "danger"
  end

  def change_display start_amount, end_amount
    change = end_amount.to_f - start_amount.to_f
    percent_change = set_num_decimals(change / start_amount.to_f * 100)
    gain = change.positive? ? "+" : ""
    "#{price_display change} (#{gain}#{percent_change}%)"
  end

  def stock_link symbol, opts={}
    #browser.device.mobile? ? yahoo_stock_link(symbol) : google_stock_link(symbol)
    opts[:target] = :_blank
    yahoo_stock_link symbol, opts
  end

  def yahoo_stock_link symbol, opts
    link_to symbol, "https://finance.yahoo.com/quote/#{symbol}", opts
  end

  def google_stock_link symbol, opts
    link_to symbol, "https://www.google.com/finance?q=#{symbol}", opts
  end

  def zacks_stock_link symbol, opts
    link_to symbol, "https://www.zacks.com/stock/quote/#{symbol}", opts
  end

  def google_stock_comparison_link symbols
    link_to symbols.join(" vs "), "https://www.google.com/finance?q=#{symbols.join(',')}", target: :_blank
  end

  def crypto_link name, opts={}
    opts[:target] = :_blank
    link_to name.titleize, "https://coinmarketcap.com/currencies/#{name.gsub(" ", "-")}", opts
  end

  def set_num_decimals amount, opts={}
    opts[:precision] ||= 2
    opts[:delimiter] ||= ','
    opts[:separator] ||= '.'
    number_with_precision amount, precision: opts[:precision], separator: opts[:separator], delimiter: opts[:delimiter]
  end
end
