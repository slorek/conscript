class WidgetMigration < ActiveRecord::Migration
  def self.up
    create_table :widgets, :force => true do |t|
      t.references :draft_parent
      t.boolean "is_draft", :default => false
      t.string :name
      t.string :file
      t.timestamps
    end

    create_table :thingies, :force => true do |t|
      t.references :widget
      t.string :name
      t.timestamps
    end
  end

  def self.down
    drop_table :widgets
    drop_table :thingies
  end
end