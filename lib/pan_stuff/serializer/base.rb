# frozen_string_literal: true

module PanStuff
  module Serializer
    module Base
      extend ActiveSupport::Concern

      TRANSFORMS_MAPPING = {
        camel_lower: %i[camelize lower],
        underscore:  :underscore,
      }.freeze

      included do
        cattr_accessor :transform_method_value, default: TRANSFORMS_MAPPING[:camel_lower]
      end

      def as_json(opts = nil)
        JSON.generate(result, opts)
      end

      def to_h
        result
      end

      alias to_hash to_h

      def serializable_hash!
        nil
      end

      def run_key_transform!(key)
        key.to_s.send(*transform_method_value).to_sym
      end

      class_methods do
        def transform_method(transform_method)
          unless TRANSFORMS_MAPPING.key?(transform_method)
            raise StandardError, "Transform method must be equal to #{TRANSFORMS_MAPPING.keys}"
          end

          self.transform_method_value = TRANSFORMS_MAPPING[transform_method]
        end

        def collection?(resource)
          resource.is_a?(Enumerable) && !resource.respond_to?(:each_pair)
        end
      end

      private

      def result
        @result ||= serializable_hash!
      end
    end
  end
end
