class AddGroupToStockList < ActiveRecord::Migration[5.0]
  def change
    add_column :stock_lists, :group, :string
  end
end
