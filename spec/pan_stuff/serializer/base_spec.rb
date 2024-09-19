# frozen_string_literal: true

require 'spec_helper'

class ExampleBaseSerializerMock
  include ActiveModel::Model

  include PanStuff::Serializer::Base
end

RSpec.describe PanStuff::Serializer::Base do
  subject(:example) { ExampleBaseSerializerMock.new }

  it { is_expected.to respond_to :serializable_hash! }
  it { is_expected.to respond_to :as_json }
  it { is_expected.to respond_to :to_h }
  it { is_expected.to respond_to :run_key_transform! }

  it 'is expected to respond to .transform_method' do
    expect(ExampleBaseSerializerMock).to respond_to :transform_method
  end

  it 'is expected to respond to .collection?' do
    expect(ExampleBaseSerializerMock).to respond_to :collection?
  end

  describe '#to_h' do
    it { expect(example.to_h).to be_nil }
  end

  describe '#as_json' do
    it { expect(example.as_json).to eq 'null' }
  end

  describe '#run_key_transform!' do
    describe 'with underscore value set' do
      before do
        example.transform_method_value = :underscore
      end

      it 'is expected to eq :example_underscore' do
        expect(example.run_key_transform!(:exampleUnderscore)).to eq :example_underscore
      end
    end

    describe 'with camel lower value set' do
      before do
        example.transform_method_value = %i[camelize lower]
      end

      it 'is expected to eq :exampleUnderscore' do
        expect(example.run_key_transform!(:example_underscore)).to eq :exampleUnderscore
      end
    end
  end

  describe '.collection?' do
    describe 'with enumerable value' do
      it { expect(ExampleBaseSerializerMock.collection?([])).to be true }
    end

    describe 'with non enumerable value' do
      it { expect(ExampleBaseSerializerMock.collection?({})).to be false }
    end
  end

  describe '.transform_method' do
    it {
      expect { ExampleBaseSerializerMock.transform_method(:invalid) }
        .to raise_error(
          StandardError,
          "Transform method must be equal to #{PanStuff::Serializer::Base::TRANSFORMS_MAPPING.keys}"
        )
    }

    it 'is expected to set transform method value' do
      ExampleBaseSerializerMock.transform_method(:camel_lower)
      expect(ExampleBaseSerializerMock.transform_method_value)
        .to eq(PanStuff::Serializer::Base::TRANSFORMS_MAPPING[:camel_lower])
    end
  end
end
