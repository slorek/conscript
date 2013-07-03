require 'conscript'
require 'nulldb_rspec'

ActiveRecord::Base.configurations['test'] = {adapter: :nulldb}
ActiveRecord::Migration.verbose = false

include NullDB::RSpec::NullifiedDatabase
