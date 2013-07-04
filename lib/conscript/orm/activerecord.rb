require 'active_record'
require 'conscript/exception/already_draft'

module Conscript
  module ActiveRecord
    def register_for_draft(options = {})

      default_scope { where(is_draft: false) }

      belongs_to :draft_parent, class_name: self
      has_many :drafts, conditions: {is_draft: true}, class_name: self, foreign_key: :draft_parent_id, dependent: :destroy, inverse_of: :draft_parent
      
      before_save :check_no_drafts_exist

      class_eval <<-RUBY
        def self.drafts
          where(is_draft: true)
        end

        def save_as_draft!
          raise Conscript::Exception::AlreadyDraft if is_draft?
          draft = new_record? ? self : dup
          draft.is_draft = true
          draft.draft_parent = self unless new_record?
          draft.save!
          draft
        end

        private
          def check_no_drafts_exist
            drafts.count == 0
          end
      RUBY
    end
  end
end

ActiveRecord::Base.extend Conscript::ActiveRecord