class CreateJoinTableInstrumentsStockLists < ActiveRecord::Migration[5.0]
  def change
    create_join_table :instruments, :stock_lists do |t|
      #t.index [:instrument_id, :stock_list_id]
      #t.index [:stock_list_id, :instrument_id]
    end
  end
end
