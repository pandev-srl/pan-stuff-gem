# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Layout/LineLength

RSpec.describe PanStuff::Serializer::SmartHashSerializer do
  let(:model) do
    {
      example_hash_data: {
        nested_data:       1,
        other_nested_data: 1,
        money_field:       Money.new(10_000, 'EUR'),
      },
    }
  end

  let(:model_collection) do
    [
      {
        example_hash_data: {
          nested_data:       1,
          other_nested_data: 1,
          money_field:       Money.new(10_000, 'EUR'),
        },
      },
      {
        example_hash_data: {
          nested_data:       2,
          other_nested_data: 2,
          money_field:       Money.new(20_000, 'EUR'),
        },
      }
    ]
  end

  let(:result_root_true) do
    JSON.generate({
                    data: {
                      exampleHashData: {
                        nestedData:      1,
                        otherNestedData: 1,
                        moneyField:      {
                          cents:         model[:example_hash_data][:money_field].cents,
                          amount:        model[:example_hash_data][:money_field].to_f,
                          currency:      model[:example_hash_data][:money_field].currency.iso_code,
                          formattedText: model[:example_hash_data][:money_field].format(
                            symbol: "#{model[:example_hash_data][:money_field].currency.symbol} "
                          ),
                          symbol:        model[:example_hash_data][:money_field].currency.symbol,
                        },
                      },
                    },
                  })
  end

  let(:result_root_false) do
    JSON.generate({
                    exampleHashData: {
                      nestedData:      1,
                      otherNestedData: 1,
                      moneyField:      {
                        cents:         model[:example_hash_data][:money_field].cents,
                        amount:        model[:example_hash_data][:money_field].to_f,
                        currency:      model[:example_hash_data][:money_field].currency.iso_code,
                        formattedText: model[:example_hash_data][:money_field].format(
                          symbol: "#{model[:example_hash_data][:money_field].currency.symbol} "
                        ),
                        symbol:        model[:example_hash_data][:money_field].currency.symbol,
                      },
                    },
                  })
  end

  let(:result_collection_root_true) do
    JSON.generate({
                    data: [
                            {
                              exampleHashData: {
                                nestedData:      1,
                                otherNestedData: 1,
                                moneyField:      {
                                  cents:         model_collection[0][:example_hash_data][:money_field].cents,
                                  amount:        model_collection[0][:example_hash_data][:money_field].to_f,
                                  currency:      model_collection[0][:example_hash_data][:money_field].currency.iso_code,
                                  formattedText: model_collection[0][:example_hash_data][:money_field].format(
                                    symbol: "#{model[:example_hash_data][:money_field].currency.symbol} "
                                  ),
                                  symbol:        model_collection[0][:example_hash_data][:money_field].currency.symbol,
                                },
                              },
                            },
                            {
                              exampleHashData: {
                                nestedData:      2,
                                otherNestedData: 2,
                                moneyField:      {
                                  cents:         model_collection[1][:example_hash_data][:money_field].cents,
                                  amount:        model_collection[1][:example_hash_data][:money_field].to_f,
                                  currency:      model_collection[1][:example_hash_data][:money_field].currency.iso_code,
                                  formattedText: model_collection[1][:example_hash_data][:money_field].format(
                                    symbol: "#{model[:example_hash_data][:money_field].currency.symbol} "
                                  ),
                                  symbol:        model_collection[1][:example_hash_data][:money_field].currency.symbol,
                                },
                              },
                            }
                          ],
                  })
  end

  let(:result_collection_root_false) do
    JSON.generate([
                    {
                      exampleHashData: {
                        nestedData:      1,
                        otherNestedData: 1,
                        moneyField:      {
                          cents:         model_collection[0][:example_hash_data][:money_field].cents,
                          amount:        model_collection[0][:example_hash_data][:money_field].to_f,
                          currency:      model_collection[0][:example_hash_data][:money_field].currency.iso_code,
                          formattedText: model_collection[0][:example_hash_data][:money_field].format(
                            symbol: "#{model[:example_hash_data][:money_field].currency.symbol} "
                          ),
                          symbol:        model_collection[0][:example_hash_data][:money_field].currency.symbol,
                        },
                      },
                    },
                    {
                      exampleHashData: {
                        nestedData:      2,
                        otherNestedData: 2,
                        moneyField:      {
                          cents:         model_collection[1][:example_hash_data][:money_field].cents,
                          amount:        model_collection[1][:example_hash_data][:money_field].to_f,
                          currency:      model_collection[1][:example_hash_data][:money_field].currency.iso_code,
                          formattedText: model_collection[1][:example_hash_data][:money_field].format(
                            symbol: "#{model[:example_hash_data][:money_field].currency.symbol} "
                          ),
                          symbol:        model_collection[1][:example_hash_data][:money_field].currency.symbol,
                        },
                      },
                    }
                  ])
  end

  describe '#as_json' do
    context 'when model is a collection' do
      context 'with root true' do
        let(:serializer) { described_class.new(model_collection) }

        it { expect(serializer.as_json).to eq(result_collection_root_true) }
      end

      context 'with root false' do
        let(:serializer) { described_class.new(model_collection, root: false) }

        it { expect(serializer.as_json).to eq(result_collection_root_false) }
      end
    end

    context 'when model is a hash' do
      context 'with root true' do
        let(:serializer) { described_class.new(model) }

        it { expect(serializer.as_json).to eq(result_root_true) }
      end

      context 'with root false' do
        let(:serializer) { described_class.new(model, root: false) }

        it { expect(serializer.as_json).to eq(result_root_false) }
      end
    end
  end
end

# rubocop:enable Layout/LineLength
