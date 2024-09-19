# frozen_string_literal: true

module PanStuff
  class MethodNotOverriddenError < StandardError
    def initialize(method, object)
      super("Method #{method} not overridden in #{object}")
    end
  end
end
