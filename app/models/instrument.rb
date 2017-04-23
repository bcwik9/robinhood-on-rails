class Instrument < ApplicationRecord
  has_and_belongs_to_many :stock_lists
end
