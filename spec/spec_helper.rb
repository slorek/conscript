require 'conscript'
Dir["./spec/support/**/*.rb"].each {|f| require f}

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveRecord::Migration.verbose = false