# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PanStuff::Serializer::MoneySerializer do
  let(:model) do
    Money.new(10_000, 'EUR')
  end

  let(:result) do
    JSON.generate(
      {
        data: {
          cents:         model.cents,
          amount:        model.to_f,
          currency:      model.currency.iso_code,
          formattedText: model.format(symbol: "#{model.currency.symbol} "),
          symbol:        model.currency.symbol,
        },
      }
    )
  end

  describe '#as_json' do
    let(:serializer) { described_class.new(model, root: true) }

    it { expect(serializer.as_json).to eq(result) }
  end
end
