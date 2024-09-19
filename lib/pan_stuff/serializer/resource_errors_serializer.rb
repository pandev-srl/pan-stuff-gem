# frozen_string_literal: true

module PanStuff
  module Serializer
    class ResourceErrorsSerializer
      include Base

      def initialize(errors)
        @resource             = errors
      end

      private

      def errors
        @resource.full_messages
      end

      def details
        @resource.details.each_with_object({}) do |error, result|
          field                             = error[0]
          errors                            = error[1]
          result[run_key_transform!(field)] = errors.map do |e|
            e.each_with_object({}) do |obj, result2|
              if obj[0] == :error
                result2[:error] = run_key_transform!(obj[1])
              else
                result2[run_key_transform!(obj[0])] = obj[1]
              end
            end
          end
        end
      end

      def serializable_hash!
        result = {}

        result[run_key_transform!(:errors)]  = errors
        result[run_key_transform!(:details)] = details

        result
      end
    end
  end
end
