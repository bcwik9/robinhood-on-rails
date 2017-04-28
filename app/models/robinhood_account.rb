class RobinhoodAccount < ApplicationRecord
  belongs_to :robinhood_user
  has_many :stock_lists
end
