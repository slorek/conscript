require 'active_record'
require 'deep_cloneable'
require 'conscript/exception/already_draft'
require 'conscript/exception/not_a_draft'

module Conscript
  module ActiveRecord
    def register_for_draft(options = {})

      cattr_accessor :conscript_options, :instance_accessor => false do
        {
          associations: [],
          ignore_attributes: [self.primary_key, 'type', 'created_at', 'updated_at', 'draft_parent_id', 'is_draft']
        }
      end

      self.conscript_options.each_pair {|key, value| self.conscript_options[key] = Array(value) | Array(options[key]) }
      self.conscript_options[:associations].map!(&:to_sym)
      self.conscript_options[:ignore_attributes].map!(&:to_s)

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
          draft = new_record? ? self : dup(include: self.class.conscript_options[:associations])
          draft.is_draft = true
          draft.draft_parent = self unless new_record?
          draft.save!
          draft
        end

        def publish_draft
          raise Conscript::Exception::NotADraft unless is_draft?
          return self.update_attribute(:is_draft, false) if !draft_parent_id
          ::ActiveRecord::Base.transaction do
            draft_parent.assign_attributes attributes_to_publish, without_protection: true

            self.class.conscript_options[:associations].each do |association|
              case reflections[association].macro
                when :has_many
                  draft_parent.send(association.to_s + "=", self.send(association).collect {|child| child.dup })
              end
            end

            self.destroy
            draft_parent.save!
          end
          draft_parent
        end

        private
          def check_no_drafts_exist
            drafts.count == 0
          end

          def attributes_to_publish
            attributes.reject {|attribute| self.class.conscript_options[:ignore_attributes].include?(attribute) }
          end
      RUBY
    end
  end
end

ActiveRecord::Base.extend Conscript::ActiveRecord