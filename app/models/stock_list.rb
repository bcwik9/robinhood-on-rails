class StockList < ApplicationRecord
  belongs_to :robinhood_account
  has_and_belongs_to_many :instruments

  validates :name, uniqueness: { scope: [:robinhood_account, :group]}
end
