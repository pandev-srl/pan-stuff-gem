# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PanStuff::Serializer::HashSerializer do
  let(:model) do
    {
      example_hash_data: {
        nested_data:       1,
        other_nested_data: 1,
      },
    }
  end

  let(:model_collection) do
    [
      {
        example_hash_data: {
          nested_data:       1,
          other_nested_data: 1,
        },
      },
      {
        example_hash_data: {
          nested_data:       2,
          other_nested_data: 2,
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
                      },
                    },
                  })
  end

  let(:result_root_false) do
    JSON.generate({
                    exampleHashData: {
                      nestedData:      1,
                      otherNestedData: 1,
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
                              },
                            },
                            {
                              exampleHashData: {
                                nestedData:      2,
                                otherNestedData: 2,
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
                      },
                    },
                    {
                      exampleHashData: {
                        nestedData:      2,
                        otherNestedData: 2,
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

  describe '#data' do
    let(:serializer) { described_class.new(model) }

    it { expect(serializer.data).to eq(model) }
  end
end
