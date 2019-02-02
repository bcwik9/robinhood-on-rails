class RobinhoodUser < ApplicationRecord
  has_many :robinhood_accounts
  has_many :stock_lists, through: :robinhood_accounts

  def main_account
    robinhood_accounts.first
  end

  # ensures that all instruments are contained in at least one stock list for a group.
  def update_stock_list group, instruments
    main_account.stock_lists.create!(group: group, name: nil) unless stock_lists.exists?(group: group)
    lists = stock_lists.where(group: group)
    default = lists.find_or_create_by(name: nil)

    database_instruments = Instrument.where url: instruments.map{|i| i["url"]}
    instruments.each do |instrument|
      database_instrument = database_instruments.find_by url: instrument["url"]
      next if lists.any?{|l| l.instruments.include? database_instrument}
      default.instruments << instrument
    end
    lists.each do |list|
      list.instruments.each{|i| list.instruments.delete i unless database_instruments.include? i}
    end
    lists
  end

end
