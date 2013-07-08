require 'spec_helper'

describe Conscript::ActiveRecord do

  before(:all) { WidgetMigration.up }
  after(:all) { WidgetMigration.down }
  after { Widget.unscoped.delete_all }

  describe "#register_for_draft" do
    it "is defined on subclasses of ActiveRecord::Base" do
      Widget.respond_to?(:register_for_draft).should == true
    end

    it "creates the default scope" do
      Widget.should_receive(:default_scope).once
      Widget.register_for_draft
    end

    it "creates a belongs_to association" do
      Widget.should_receive(:belongs_to).once.with(:draft_parent, kind_of(Hash))
      Widget.register_for_draft
    end

    it "creates a has_many association" do
      Widget.should_receive(:has_many).once.with(:drafts, kind_of(Hash))
      Widget.register_for_draft
    end

    it "creates a before_save callback" do
      Widget.should_receive(:before_save).once.with(:check_no_drafts_exist)
      Widget.register_for_draft
    end

    it "accepts options and merges them with defaults" do
      Widget.register_for_draft(associations: :owners, ignore_attributes: :custom_attribute)
      Widget.conscript_options[:associations].should == [:owners]
      Widget.conscript_options[:ignore_attributes].should == ["id", "type", "created_at", "updated_at", "draft_parent_id", "is_draft", "custom_attribute"]
    end

    describe "CarrierWave compatibility" do
      context "where no uploaders are defined on the class" do
        it "does not try to skip callbacks" do
          Widget.should_not_receive :skip_callback
          Widget.register_for_draft
        end
      end

      context "where uploaders are defined on the class" do
        before do
          Widget.cattr_accessor :uploaders
          Widget.uploaders = {file: nil}
        end

        it "disables the provided remove_#attribute callback behaviour" do
          Widget.should_receive(:skip_callback).with(:commit, :after, :remove_file!)
          Widget.register_for_draft
        end

        it "registers a callback to #clean_uploaded_files_for_draft" do
          Widget.should_receive(:after_commit).with(:clean_uploaded_files_for_draft!, :on => :destroy)
          Widget.register_for_draft
        end
      end
    end
  end

  describe "#drafts" do
    it "limits results to drafts" do
      Widget.register_for_draft
      Widget.should_receive(:where).once.with(is_draft: true)
      Widget.drafts
    end
  end

  describe "#check_no_drafts_exist" do
    before do
      Widget.register_for_draft
      @subject = Widget.new
    end

    context "when no drafts exist" do
      before do
        @subject.stub_chain(:drafts, :count).and_return(0)
      end

      it "returns true" do
        @subject.send(:check_no_drafts_exist).should == true
      end
    end
    context "when drafts exist" do
      before do
        @subject.stub_chain(:drafts, :count).and_return(1)
      end
      
      it "returns false" do
        @subject.send(:check_no_drafts_exist).should == false
      end
    end
  end

  describe "#clean_uploaded_files_for_draft!" do
    before do
      Widget.cattr_accessor :uploaders
      Widget.uploaders = {file: nil}
      Widget.register_for_draft
    end

    context "where files are not shared with any other instances" do
      before do
        @original = Widget.create(file: 'test.jpg')
        @duplicate = @original.save_as_draft!
        @duplicate.file = 'another_file.jpg'
        @duplicate.save
        @original.reload
      end

      it "should not attempt to remove the file" do
        @duplicate.should_receive(:remove_file!)
        @duplicate.destroy
      end
    end

    context "where files are shared with other instances" do
      before do
        @original = Widget.create(file: 'test.jpg')
        @duplicate = @original.save_as_draft!
        @duplicate.file.should == 'test.jpg'
        @original.reload
      end

      it "should not attempt to remove the file" do
        @duplicate.should_not_receive(:remove_file!)
        @duplicate.destroy
      end
    end
  end

  describe "#save_as_draft!" do
    before { Widget.register_for_draft }

    context "where the instance is a draft" do
      it "raises an exception" do
        -> { Widget.new(is_draft: true).save_as_draft! }.should raise_error Conscript::Exception::AlreadyDraft
      end
    end

    context "where the instance is not a draft" do
      before do
        @subject = Widget.new
      end

      context "and is a new record" do
        before do
          @subject.stub(:new_record?).and_return(true)
        end

        it "saves as a draft" do
          @subject.should_receive("is_draft=").once.with(true)
          @subject.should_not_receive("draft_parent=")
          @subject.should_receive("save!").once
          @subject.save_as_draft!
        end

        it "returns the instance" do
          @subject.save_as_draft!.should == @subject
        end
      end

      context "and is persisted" do
        before do
          @subject.stub(:new_record?).and_return(false)
          @duplicate = Widget.new
          @subject.should_receive(:dup).once.and_return(@duplicate)
        end

        it "saves a duplicate record as a draft" do
          @duplicate.should_receive("is_draft=").once.with(true)
          @duplicate.should_receive("draft_parent=").once.with(@subject)
          @duplicate.should_receive("save!").once
          @subject.save_as_draft!
        end

        it "returns the duplicate instance" do
          @subject.save_as_draft!.should == @duplicate
        end
      end

      context "and has associations" do
        before do
          @subject.save!
          @subject.thingies.create(name: 'Thingy')
        end

        context "and the association is not specified in register_for_draft" do
          before do
            Widget.register_for_draft associations: nil
            @duplicate = @subject.save_as_draft!
          end

          it "does not duplicate the associated records" do
            @duplicate.thingies.count.should == 0
          end
        end

        context "and the association is specified in register_for_draft" do
          before do
            Widget.register_for_draft associations: :thingies
            @duplicate = @subject.save_as_draft!
          end

          it "duplicates the associated records" do
            @subject.thingies.count.should == 1
            @duplicate.thingies.count.should == 1
            @duplicate.thingies.first.name.should == @subject.thingies.first.name
            @duplicate.thingies.first.id.should_not == @subject.thingies.first.id
          end
        end
      end
    end
  end

  describe "#publish_draft" do
    before { Widget.register_for_draft }

    context "where the instance is not a draft" do
      it "raises an exception" do
        -> { Widget.new.publish_draft }.should raise_error Conscript::Exception::NotADraft
      end
    end

    context "where the instance is a draft" do
      context "and has no parent" do
        before do
          @subject = Widget.new.save_as_draft!
        end

        it "sets is_draft to false and saves" do
          @subject.is_draft?.should == true
          @subject.publish_draft
          @subject.is_draft?.should == false
        end
      end

      context "and has a parent instance" do
        before do
          @original = Widget.create(name: 'Old name')
          @duplicate = @original.save_as_draft!
        end

        it "copies the attributes to the parent" do
          @duplicate.name = 'New name'
          @duplicate.publish_draft
          @original.reload
          @original.name.should == 'New name'
        end

        it "does not copy the ID, type, draft or timestamp attributes" do
          @duplicate.name = 'New name'
          @duplicate.publish_draft
          @original.reload
          @original.id.should_not == @duplicate.id
          @original.created_at.should_not == @duplicate.created_at
          @original.updated_at.should_not == @duplicate.updated_at
          @original.is_draft.should_not == @duplicate.is_draft
          @original.draft_parent_id.should_not == @duplicate.draft_parent_id
        end

        it "destroys the draft instance" do
          @duplicate.publish_draft
          -> { @duplicate.reload }.should raise_error(ActiveRecord::RecordNotFound)
        end

        it "destroys the parent's other drafts" do
          3.times { @original.save_as_draft! }
          @original.drafts.count.should == 4
          @duplicate.publish_draft
          @original.drafts.count.should == 0
        end

        context "where attributes were excluded in register_for_draft" do
          before { Widget.register_for_draft ignore_attributes: :name }

          it "does not copy the excluded attributes" do
            @duplicate.name = 'New name'
            @duplicate.publish_draft
            @original.reload
            @original.name.should == 'Old name'
          end
        end

        describe "copying associations" do
          def setup
            @original.thingies.count.should == 0
            @duplicate.save!
            @duplicate.thingies.create(name: 'Thingy')
            @duplicate.publish_draft
            @original.reload
          end

          context "when associations were specified in register_for_draft" do
            before do
              Widget.register_for_draft associations: :thingies
              setup
            end

            it "copies has_many associations to the parent" do
              @original.thingies.count.should == 1
            end
          end

          context "when no associations were specified in register_for_draft" do
            before do
              Widget.register_for_draft associations: nil
              setup
            end

            it "does not copy associations to the parent" do
              @original.thingies.count.should == 0
            end
          end
        end
      end
    end
  end

  describe "#uploader_store_param" do
    before do
      Widget.register_for_draft
      @original = Widget.create
      @duplicate = @original.save_as_draft!
      @draft = Widget.new.save_as_draft!
    end

    context "where the instance is not a draft" do
      it "returns #to_param" do
        @original.uploader_store_param.should == @original.to_param
      end
    end

    context "where the instance is a draft" do
      context "and it has no draft_parent" do
        it "returns #to_param" do
          @draft.uploader_store_param.should == @draft.to_param
        end
      end
      context "and it has a draft_parent" do
        it "returns draft_parent#to_param" do
          @duplicate.uploader_store_param.should == @original.to_param
        end
      end
    end
  end
end