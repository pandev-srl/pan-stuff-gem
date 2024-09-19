# frozen_string_literal: true

module PanStuff
  module Serializer
    class SmartHashSerializer < HashSerializer
      def initialize(resource, meta: nil, message: nil, context: nil, root: true)
        super(
          check_type(resource),
          meta:    meta,
          message: message,
          context: context,
          root:    root,
        )
      end

      private

      def check_type(stuff)
        case stuff
        when Array
          stuff.map { |s| check_type(s) }
        when Hash
          stuff.transform_values { |v| check_type(v) }
        when Money
          MoneySerializer.new(stuff, root: false).data
        else
          stuff
        end
      end
    end
  end
end
