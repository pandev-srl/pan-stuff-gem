# frozen_string_literal: true

module PanStuff
  module Serializer
    class ValidationResponseSerializer
      include Base

      attr_reader :message

      def initialize(resource, message = nil)
        @resource             = resource
        @message              = message
      end

      protected

      def validation_response
        @resource.attributes.symbolize_keys.deep_transform_keys do |k|
          run_key_transform!(k)
        end
      end

      def serializable_hash!
        result = {}

        result[run_key_transform!(:validation_response)] = validation_response
        result[run_key_transform!(:message)]             = message if message

        result
      end
    end
  end
end
