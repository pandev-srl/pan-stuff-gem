# frozen_string_literal: true

require 'zeitwerk'

require 'active_model'
require 'json'
require 'money'

loader = Zeitwerk::Loader.for_gem
loader.setup

module PanStuff
end
