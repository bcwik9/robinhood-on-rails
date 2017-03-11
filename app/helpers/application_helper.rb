module ApplicationHelper
  def price_display amount
    "$#{set_num_decimals amount}"
  end

  def change_display start_amount, end_amount
    change = set_num_decimals(end_amount.to_f - start_amount.to_f).to_f
    gain = change.positive? ? "+" : ""
    "#{price_display change} (#{gain}#{set_num_decimals change/start_amount.to_f*100}%)"
  end

  def set_num_decimals amount, decimal_points=2
    sprintf("%.#{decimal_points}f", amount)
  end
end
