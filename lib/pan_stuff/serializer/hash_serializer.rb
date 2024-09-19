# frozen_string_literal: true

module PanStuff
  module Serializer
    class HashSerializer
      include Base

      attr_reader :hash, :meta, :message, :root

      def initialize(resource, meta: nil, message: nil, context: nil, root: true)
        @hash     = resource
        @resource = resource
        @meta     = meta
        @message  = message
        @context  = context || {}
        @root     = root
      end

      def data
        hash
      end

      protected

      def serializable_hash!
        if root
          result = {}

          result[run_key_transform!(:data)]    = serialize_data
          result[run_key_transform!(:meta)]    = meta&.deep_transform_keys { |key| run_key_transform!(key) } if meta
          result[run_key_transform!(:message)] = message if message

          result
        else
          serialize_data
        end
      end

      def serialize_data
        if self.class.collection? @resource
          @resource.map { |o| o.deep_transform_keys { |key| run_key_transform!(key) } }
        else
          @resource&.deep_transform_keys { |key| run_key_transform!(key) }
        end
      end
    end
  end
end
