module ApplicationHelper
  def price_display amount
    "$#{set_num_decimals amount}"
  end

  def up_down start_amount, end_amount
    change_display(start_amount, end_amount).include?('+') ? "text-success" : "text-danger"
  end

  def change_display start_amount, end_amount
    change = set_num_decimals(end_amount.to_f - start_amount.to_f).to_f
    gain = change.positive? ? "+" : ""
    "#{price_display change} (#{gain}#{set_num_decimals change/start_amount.to_f*100}%)"
  end

  def stock_link symbol
    #browser.device.mobile? ? yahoo_stock_link(symbol) : google_stock_link(symbol)
    yahoo_stock_link symbol
  end

  def yahoo_stock_link symbol
    link_to symbol, "https://finance.yahoo.com/quote/#{symbol}", target: :_blank
  end

  def google_stock_link symbol
    link_to symbol, "https://www.google.com/finance?q=#{symbol}", target: :_blank
  end

  def google_stock_comparison_link symbols
    link_to symbols.join(" vs "), "https://www.google.com/finance?q=#{symbols.join(',')}", target: :_blank
  end

  def set_num_decimals amount, decimal_points=2
    sprintf("%.#{decimal_points}f", amount)
  end
end
