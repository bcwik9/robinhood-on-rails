class StockList < ApplicationRecord
  belongs_to :robinhood_account
  has_and_belongs_to_many :intruments

  validates :group, presence: true, uniqueness: { scope: :robinhood_account}
end
