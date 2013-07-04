class WidgetMigration < ActiveRecord::Migration
  def self.up
    create_table :widgets, :force => true do |t|
      t.integer "draft_parent_id"
      t.boolean "is_draft", :default => false
    end
  end

  def self.down
    drop_table :widgets
  end
end