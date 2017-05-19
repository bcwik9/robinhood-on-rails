class RobinhoodAccount < ApplicationRecord
  belongs_to :robinhood_user
  has_many :stock_lists

  def url
    'https://api.robinhood.com/accounts/' + account_number + '/'
  end
end
