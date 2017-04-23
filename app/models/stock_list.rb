class StockList < ApplicationRecord
  belongs_to :robinhood_account
  has_and_belongs_to_many :intruments
end
