# frozen_string_literal: true

module PanStuff
  module Serializer
    module ObjectSerializer
      extend ActiveSupport::Concern
      include Base

      included do
        class << self
          attr_writer :attributes_to_serialize

          def attributes_to_serialize
            @attributes_to_serialize ||= []
          end
        end

        attr_reader :resource, :message, :context, :root
      end

      def initialize(resource, meta: nil, message: nil, context: nil, root: true)
        @resource = resource
        @meta     = meta
        @message  = message
        @context  = context || {}
        @root     = root
      end

      class_methods do
        def attribute(key, options = {})
          attributes_to_serialize.push({
                                         name: key,
                                         **options.slice(:method, :serializer, :serialize_if),
                                       })
        end
      end

      def data
        if self.class.collection? @resource
          data_for_collection
        else
          data_for_one_record
        end
      end

      def meta
        @meta&.deep_transform_keys do |k|
          run_key_transform!(k)
        end
      end

      def serializable_hash!
        if root
          use_root
        else
          data
        end
      end

      private

      def data_for_collection
        @resource.map { |el| build_record(el) }
      end

      def data_for_one_record
        build_record(@resource) if @resource
      end

      def build_record(record)
        self.class.attributes_to_serialize.each_with_object({}) do |attr, hash|
          name         = attr[:name]
          serializer   = attr[:serializer]
          method       = attr[:method]
          serialize_if = attr[:serialize_if]

          next if serialize_if && !serialize_if.call(context)

          hash[run_key_transform!(name)] = if serializer.present?
                                             attr[:serializer].new(record.send(name), root: false, context: context)
                                               .to_h
                                           elsif method.present?
                                             send(method, record)
                                           else
                                             record.send(name)
                                           end
        end
      end

      def use_root
        result = {}

        result[run_key_transform!(:data)]    = data
        result[run_key_transform!(:meta)]    = meta if @meta.present?
        result[run_key_transform!(:message)] = message if @message.present?

        result
      end
    end
  end
end
