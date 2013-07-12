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
          ignore_attributes: [self.primary_key, 'type', 'created_at', 'updated_at', 'draft_parent_id', 'is_draft'],
          allow_update_with_drafts: false,
          destroy_drafts_on_publish: true
        }
      end

      self.conscript_options.slice(:associations, :ignore_attributes).each_pair {|key, value| self.conscript_options[key] = Array(value) | Array(options[key]) }
      self.conscript_options[:associations].map!(&:to_sym)
      self.conscript_options[:ignore_attributes].map!(&:to_s)
      self.conscript_options.update options.slice(:allow_update_with_drafts, :destroy_drafts_on_publish)

      belongs_to :draft_parent, class_name: self
      has_many :drafts, conditions: {is_draft: true}, class_name: self, foreign_key: :draft_parent_id, dependent: :destroy, inverse_of: :draft_parent

      define_callbacks :publish_draft, :save_as_draft

      before_save :check_no_drafts_exist if (self.conscript_options[:allow_update_with_drafts] == false)
      set_callback :publish_draft, :after, :destroy_all_drafts if (self.conscript_options[:destroy_drafts_on_publish] == true)

      # Prevent deleting CarrierWave uploads which may be used by other instances. Uploaders must be mounted beforehand.
      if self.respond_to? :uploaders
        self.uploaders.keys.each {|attribute| skip_callback :commit, :after, :"remove_#{attribute}!" }
        after_commit :clean_uploaded_files_for_draft!, :on => :destroy
      end

      class_eval <<-RUBY
        def self.published
          where(is_draft: false)
        end

        def self.drafts
          where(is_draft: true)
        end

        def save_as_draft!
          run_callbacks :save_as_draft do
            raise Conscript::Exception::AlreadyDraft if is_draft?
            draft = new_record? ? self : dup(include: self.class.conscript_options[:associations]) do |original, dup|
              # Workaround for CarrierWave uploaders on associated records. Copy the uploaded files.
              if dup.class.respond_to? :uploaders
                dup.class.uploaders.keys.each {|uploader| dup.send(uploader.to_s + "=", original.send(uploader)) }
              end
            end
            draft.is_draft = true
            draft.draft_parent = self unless new_record?
            draft.save!
            draft
          end
        end

        def publish_draft
          run_callbacks :publish_draft do
            raise Conscript::Exception::NotADraft unless is_draft?
            return self.update_attribute(:is_draft, false) if !draft_parent_id
            ::ActiveRecord::Base.transaction do
              draft_parent.assign_attributes attributes_to_publish, without_protection: true

              self.class.conscript_options[:associations].each do |association|
                case reflections[association].macro
                  when :has_many
                    draft_parent.send(association.to_s + "=", self.send(association).collect {|child| child.dup do |original, dup|
                      # Workaround for CarrierWave uploaders on associated records. Copy the uploaded files.
                      if dup.class.respond_to? :uploaders
                        dup.class.uploaders.keys.each {|uploader| dup.send(uploader.to_s + "=", original.send(uploader)) }
                      end
                    end })
                end
              end

              self.destroy
              draft_parent.save!
            end
            draft_parent
          end
        end

        def uploader_store_param
          draft_parent_id.nil? ? to_param : draft_parent.to_param
        end

        private
          def check_no_drafts_exist
            errors[:base] << "Cannot save record while drafts exist"
            drafts.count == 0
          end

          def attributes_to_publish
            attributes.reject {|attribute| self.class.conscript_options[:ignore_attributes].include?(attribute) }
          end

          # Clean up CarrierWave uploads if there are no other instances using the files.
          #
          def clean_uploaded_files_for_draft!
            self.class.uploaders.keys.each do |attribute|
              filename = attributes[attribute.to_s]
              cols = self.class.arel_table
              self.send("remove_" + attribute.to_s + "!") if !draft_parent_id or self.class.where(cols[:id].eq(draft_parent_id).or(cols[:draft_parent_id].eq(draft_parent_id))).where(attribute => filename).count == 0
            end
          end

          def destroy_all_drafts
            draft_parent.drafts.destroy_all if draft_parent_id
          end
      RUBY
    end
  end
end

ActiveRecord::Base.extend Conscript::ActiveRecord