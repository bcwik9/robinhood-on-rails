class CreateInstruments < ActiveRecord::Migration[5.0]
  def change
    create_table :instruments do |t|
      t.string :url
      t.string :symbol
      t.string :quote_url
      t.string :fundamentals_url
      t.string :robinhood_id
      t.string :name

      t.timestamps
    end
  end
end
