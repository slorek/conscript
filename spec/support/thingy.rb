class Thingy < ActiveRecord::Base
  belongs_to :widget
  validates :widget, presence: true
end