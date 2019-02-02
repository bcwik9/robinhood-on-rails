class RenameDefaultWatchList < ActiveRecord::Migration[5.0]
  def up
    StockList.where(group: "watchlist").find_each do |list|
      list.update! group: "Default"
    end
  end

  def down
    StockList.where(group: "Default").find_each do |list|
      list.update! group: "watchlist"
    end
  end
end
