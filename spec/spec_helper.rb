# frozen_string_literal: true

require 'simplecov'
require 'simplecov_json_formatter'

FORMATTERS = [
               SimpleCov::Formatter::HTMLFormatter,
               SimpleCov::Formatter::JSONFormatter
             ].freeze

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(FORMATTERS)
SimpleCov.start do
  load_profile 'test_frameworks'

  add_filter %r{^/config/}
  add_filter %r{^/db/}

  add_group 'Serializer', 'lib/pan_stuff/serializer'

  track_files '{lib}/**/*.rb'

  # # minimum_coverage 100
  add_filter 'spec/'
  add_filter 'lib/pan_stuff.rb'
  add_filter 'lib/pan_stuff/railtie.rb'
  add_filter 'lib/pan_stuff/serializer.rb'
  add_filter 'lib/pan_stuff/version.rb'
end

RSpec.configure do |config|
  config.before(:suite) do
    PanStuff::Railtie.initializers.each(&:run)
  end

  config.expect_with :rspec do |expectations|
    expectations.syntax                                               = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.max_formatted_output_length                          = 1_000_000
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax                 = :expect
    mocks.verify_partial_doubles = true
  end

  config.raise_errors_for_deprecations!
  config.disable_monkey_patching!

  config.default_formatter = 'doc' if config.files_to_run.one?
  config.filter_run_when_matching(:focus)

  config.silence_filter_announcements = true
  config.fail_if_no_examples          = true
  config.warnings                     = false
  config.raise_on_warning             = true
  config.threadsafe                   = true

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order                            = :random
  Kernel.srand(config.seed)
end

ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('dummy/config/environment', __dir__)

require 'rspec/rails'

require 'plugins/money'
require 'plugins/in_memory_database'
require 'support/examples'
