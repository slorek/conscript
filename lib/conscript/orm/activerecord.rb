require 'active_record'

module Conscript
  module ActiveRecord
    def register_for_draft(options = {})
      default_scope { where(is_draft: false) }
    end
  end
end

ActiveRecord::Base.extend Conscript::ActiveRecord