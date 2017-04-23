class CreateStockLists < ActiveRecord::Migration[5.0]
  def change
    create_table :stock_lists do |t|
      t.string :name
      t.integer :robinhood_account_id

      t.timestamps
    end
  end
end
