require "zeitwerk"

require 'active_model'
require 'json'
require 'money'

loader = Zeitwerk::Loader.for_gem
loader.setup
loader.eager_load

module PanStuff
end
