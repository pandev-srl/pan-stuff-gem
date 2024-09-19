require "zeitwerk"

require 'active_model'
require 'json'
require 'money'

loader = Zeitwerk::Loader.for_gem
loader.enable_reloading
loader.setup

module PanStuff
end
