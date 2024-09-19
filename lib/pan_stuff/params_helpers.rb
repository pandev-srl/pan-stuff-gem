# frozen_string_literal: true

module PanStuff
  module ParamsHelpers
    extend ActiveSupport::Concern

    def request_params
      request.request_parameters.to_h.deep_symbolize_keys
    end

    def query_params
      res = request.query_parameters.deep_transform_keys(&:underscore).deep_symbolize_keys

      parse_query_params(res)
    end

    private

    def parse_query_params(val)
      case val
      when ->(v) { v.is_a?(Hash) }
        val.transform_values do |val2|
          parse_query_params(val2)
        end
      when ->(v) { v.is_a?(Array) }
        val.map { |v| parse_query_params(v) }
      when 'null', 'undefined'
        nil
      else
        val
      end
    end
  end
end
