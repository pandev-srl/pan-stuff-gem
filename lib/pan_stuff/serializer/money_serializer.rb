# frozen_string_literal: true

module PanStuff
  module Serializer
    class MoneySerializer
      include ObjectSerializer

      attribute :cents, method: :cents
      attribute :amount, method: :amount
      attribute :currency, method: :currency
      attribute :formatted_text, method: :formatted_text
      attribute :symbol, method: :symbol

      def cents(record)
        record.cents
      end

      def amount(record)
        record.to_f
      end

      def currency(record)
        record.currency.iso_code
      end

      def formatted_text(record)
        record.format(symbol: "#{record.currency.symbol} ")
      end

      def symbol(record)
        record.currency.symbol
      end
    end
  end
end
