module InMemoryDatabaseHelpers
  extend ActiveSupport::Concern

  class_methods do
    def switch_to_SQLite(&block)
      before(:each) { switch_to_in_memory_database(&block) }
      after(:each) { switch_back_to_test_database }
    end
  end

  private

  def switch_to_in_memory_database(&block)
    raise 'No migration given' unless block_given?

    ActiveRecord::Migration.verbose = false
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define(version: 1, &block)
  end

  def switch_back_to_test_database
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
  end
end