require 'spec_helper'

class TestModel < ActiveRecord::Base; end

class TestMigration < ActiveRecord::Migration
  def self.up
    create_table :test_model, :force => true do |t|
    t.integer  "draft_parent_id"
    t.boolean  "is_draft", :default => false
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

    it "creates the drafts scope" do
      TestModel.should_receive(:default_scope).once
      TestModel.register_for_draft
    end
  end

end