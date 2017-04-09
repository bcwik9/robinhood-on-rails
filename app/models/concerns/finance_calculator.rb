module FinanceCalculator
  def simple_moving_average arr, period
    return [] if arr.size < period
    i = period
    sma = []
    while i < arr.size do
      sma << avg(arr[i-period..i])
      i += 1
    end
    sma
  end

  # average
  def avg arr
    arr.sum / arr.size.to_f
  end
end
