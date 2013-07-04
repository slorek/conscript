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
  end

  describe "#drafts" do
    it "limits results to drafts" do
      Widget.should_receive(:where).once.with(is_draft: true)
      Widget.drafts
    end
  end

  describe "#check_no_drafts_exist" do
    before do
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

  describe "#save_as_draft!" do
    context "where the instance is a draft" do
      it "raises an exception" do
        lambda { Widget.new(is_draft: true).save_as_draft! }.should raise_error Conscript::Exception::AlreadyDraft
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
    end
  end
end