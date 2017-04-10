module FinanceCalculator
  def simple_moving_average arr, period
    return [] if arr.size < period
    i = period
    sma = []
    while i < arr.size do
      sma << arr[i-period..i].simple_moving_average
      i += 1
    end
    sma
  end

end
