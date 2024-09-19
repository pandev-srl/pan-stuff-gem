# frozen_string_literal: true

module PanStuff
  module Serializer
    class ExceptionSerializer
      include Base

      attr_reader :error, :status, :exception, :root

      def initialize(status: nil, error: nil, exception: nil, root: true)
        @error     = error
        @status    = status
        @exception = exception
        @root      = root
      end

      protected

      def serializable_hash!
        data   = {}
        result = {}

        data[run_key_transform!(:status)]    = status
        data[run_key_transform!(:error)]     = error if error
        data[run_key_transform!(:exception)] = exception if exception

        if root
          result[run_key_transform!(:validation_response)] = data
          result
        else
          data
        end
      end
    end
  end
end
