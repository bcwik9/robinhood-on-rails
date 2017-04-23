class CreateRobinhoodAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :robinhood_accounts do |t|
      t.string :account_number
      t.integer :robinhood_user_id

      t.timestamps
    end
  end
end
