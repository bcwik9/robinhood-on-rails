class CreateRobinhoodUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :robinhood_users do |t|
      t.string :first_name
      t.string :last_name
      t.string :username
      t.string :email
      t.string :robinhood_id

      t.timestamps
    end
  end
end
