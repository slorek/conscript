require 'spec_helper'

class TestModel < ActiveRecord::Base; end

class TestMigration < ActiveRecord::Migration
  def self.up
    create_table :test_model, :force => true do |t|
      t.integer "draft_parent_id"
      t.boolean "is_draft", :default => false
    end
  end

  def self.down
    drop_table :test_model
  end
end


describe Conscript::ActiveRecord do

  before(:all) { TestMigration.up }
  after(:all) { TestMigration.down }
  after { TestModel.unscoped.delete_all }

  describe "#register_for_draft" do
    it "is defined on subclasses of ActiveRecord::Base" do
      TestModel.respond_to?(:register_for_draft).should == true
    end

    it "creates the default scope" do
      TestModel.should_receive(:default_scope).once
      TestModel.register_for_draft
    end

    it "creates a belongs_to association" do
      TestModel.should_receive(:belongs_to).once.with(:draft_parent, kind_of(Hash))
      TestModel.register_for_draft
    end

    it "creates a has_many association" do
      TestModel.should_receive(:has_many).once.with(:drafts, kind_of(Hash))
      TestModel.register_for_draft
    end

    it "creates a before_save callback" do
      TestModel.should_receive(:before_save).once.with(:check_no_drafts_exist)
      TestModel.register_for_draft
    end
  end

  describe "#drafts" do
    it "limits results to drafts" do
      TestModel.should_receive(:where).once.with(is_draft: true)
      TestModel.drafts
    end
  end

  describe "#check_no_drafts_exist" do
    before do
      @subject = TestModel.new
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
end