class RobinhoodUser < ApplicationRecord
  has_many :robinhood_accounts
  has_many :stock_lists, through: :robinhood_accounts

  def main_account
    robinhood_accounts.first
  end

  def update_stock_list group, instruments
    lists = stock_lists.where(group: group)
    lists << main_account.stock_lists.create!(group: group, name: nil) if lists.nil? || lists.empty?
    default = lists.find_or_create_by(name: nil)

    instruments.each do |instrument|
      database_instrument = Instrument.find_by url: instrument["url"]
      next if lists.any?{|l| l.instruments.include? database_instrument}
      default.instruments << instrument
    end
    lists
  end
end
