# frozen_string_literal: true

# Documentation https://github.com/piotrmurach/rspec-benchmark

require 'rspec-benchmark'

RSpec.configure do |config|
  config.include RSpec::Benchmark::Matchers
end
