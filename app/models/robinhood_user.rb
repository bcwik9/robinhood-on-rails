class RobinhoodUser < ApplicationRecord

  has_many :robinhood_accounts
  has_many :stock_lists, through: :robinhood_accounts
end
