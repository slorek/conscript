class Widget < ActiveRecord::Base
  has_many :thingies, dependent: :destroy
end