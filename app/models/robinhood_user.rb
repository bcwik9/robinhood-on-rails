class RobinhoodUser < ApplicationRecord

  has_many :robinhood_accounts
  has_many :stock_lists, through: :robinhood_accounts


  def main_account
    robinhood_accounts.first
  end
end
