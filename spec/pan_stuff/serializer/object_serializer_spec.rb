# frozen_string_literal: true

require 'spec_helper'

class ExampleObjectMock
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, type: String
  attribute :with_example, type: String
  attribute :with_example_for_inherited, type: String

  def custom_method
    'it returns a content from model'
  end

  def with_custom_serializer
    ExampleObjectMock.new(name:                       'Example name',
                          with_example:               'An example',
                          with_example_for_inherited: 'Inherited example')
  end
end

class ExampleObjectSerializerMock
  include PanStuff::Serializer::ObjectSerializer

  attribute :name
  attribute :with_example

  def custom_method
    'it returns a content from serializer'
  end
end

class ExampleObjectSerializerMock2
  include PanStuff::Serializer::ObjectSerializer

  attribute :name
  attribute :with_example

  attribute :with_custom_serializer, serializer: ExampleObjectSerializerMock

  attribute :custom_method_serialized, method: :custom_method

  def custom_method(_record)
    'it returns a content from serializer 2'
  end
end

class ExampleObjectSerializerMock3
  include PanStuff::Serializer::ObjectSerializer

  transform_method :underscore

  attribute :name
  attribute :with_example
end

class InheritedExampleObjectSerializerMock < ExampleObjectSerializerMock
  include PanStuff::Serializer::ObjectSerializer

  attribute :name
  attribute :with_example
  attribute :with_example_for_inherited
end

RSpec.describe PanStuff::Serializer::ObjectSerializer do
  let(:model) do
    ExampleObjectMock.new(
      name:                       'Example name',
      with_example:               'An example',
      with_example_for_inherited: 'Inherited example'
    )
  end

  describe '#as_json' do
    example_data = [
                     {
                       serializer:       ExampleObjectSerializerMock,
                       root:             true,
                       meta:             { other_stuff_data: 1 },
                       message:          'An example message',
                       transform_method: :camel_lower,
                       result:           JSON.generate({
                                                         data:    {
                                                           name:        'Example name',
                                                           withExample: 'An example',
                                                         },
                                                         meta:    { otherStuffData: 1 },
                                                         message: 'An example message',
                                                       }),
                     },
                     {
                       serializer:       ExampleObjectSerializerMock,
                       root:             true,
                       meta:             { other_stuff_data: 1 },
                       transform_method: :camel_lower,
                       result:           JSON.generate({
                                                         data: {
                                                           name:        'Example name',
                                                           withExample: 'An example',
                                                         },
                                                         meta: { otherStuffData: 1 },
                                                       }),
                     },
                     {
                       serializer:       ExampleObjectSerializerMock,
                       root:             true,
                       meta:             { other_stuff_data: 1 },
                       transform_method: :camel_lower,
                       result:           JSON.generate({
                                                         data: {
                                                           name:        'Example name',
                                                           withExample: 'An example',
                                                         },
                                                         meta: { otherStuffData: 1 },
                                                       }),
                     },
                     {
                       serializer:       ExampleObjectSerializerMock3,
                       root:             true,
                       meta:             { other_stuff_data: 1 },
                       transform_method: :underscore,
                       result:           JSON.generate({
                                                         data: {
                                                           name:         'Example name',
                                                           with_example: 'An example',
                                                         },
                                                         meta: { other_stuff_data: 1 },
                                                       }),
                     },
                     {
                       serializer:       ExampleObjectSerializerMock,
                       root:             false,
                       meta:             nil,
                       message:          nil,
                       transform_method: :camel_lower,
                       result:           JSON.generate({
                                                         name:        'Example name',
                                                         withExample: 'An example',
                                                       }),
                     },
                     {
                       serializer:       ExampleObjectSerializerMock2,
                       root:             true,
                       meta:             nil,
                       message:          nil,
                       transform_method: :camel_lower,
                       result:           JSON.generate({
                                                         data: {
                                                           name:                   'Example name',
                                                           withExample:            'An example',
                                                           withCustomSerializer:   {
                                                             name:        'Example name',
                                                             withExample: 'An example',
                                                           },
                                                           # rubocop:disable Layout/LineLength
                                                           customMethodSerialized: 'it returns a content from serializer 2',
                                                           # rubocop:enable Layout/LineLength
                                                         },
                                                       }),
                     }
                   ]

    example_data.each_with_index do |example, idx|
      describe "Hash example #{idx}" do
        let(:serializer) do
          example[:serializer].new(model,
                                   root:    example[:root],
                                   meta:    example[:meta],
                                   message: example[:message])
        end

        it 'is serialized as result' do
          expect(serializer.as_json).to eq example[:result]
        end
      end
    end

    example_c_data = [
                       {
                         serializer:       ExampleObjectSerializerMock,
                         root:             true,
                         meta:             { other_stuff_data: 1 },
                         message:          'An example message',
                         transform_method: :camel_lower,
                         result:           JSON.generate({
                                                           data:    [
                                                                      {
                                                                        name:        'Example name',
                                                                        withExample: 'An example',
                                                                      },
                                                                      {
                                                                        name:        'Example name',
                                                                        withExample: 'An example',
                                                                      },
                                                                      {
                                                                        name:        'Example name',
                                                                        withExample: 'An example',
                                                                      }
                                                                    ],
                                                           meta:    { otherStuffData: 1 },
                                                           message: 'An example message',
                                                         }),
                       },
                       {
                         serializer:       ExampleObjectSerializerMock,
                         root:             true,
                         meta:             { other_stuff_data: 1 },
                         transform_method: :camel_lower,
                         result:           JSON.generate({
                                                           data: [
                                                                   {
                                                                     name:        'Example name',
                                                                     withExample: 'An example',
                                                                   },
                                                                   {
                                                                     name:        'Example name',
                                                                     withExample: 'An example',
                                                                   },
                                                                   {
                                                                     name:        'Example name',
                                                                     withExample: 'An example',
                                                                   }
                                                                 ],
                                                           meta: { otherStuffData: 1 },
                                                         }),
                       },
                       {
                         serializer:       ExampleObjectSerializerMock,
                         root:             true,
                         meta:             { other_stuff_data: 1 },
                         transform_method: :camel_lower,
                         result:           JSON.generate({
                                                           data: [
                                                                   {
                                                                     name:        'Example name',
                                                                     withExample: 'An example',
                                                                   },
                                                                   {
                                                                     name:        'Example name',
                                                                     withExample: 'An example',
                                                                   },
                                                                   {
                                                                     name:        'Example name',
                                                                     withExample: 'An example',
                                                                   }
                                                                 ],
                                                           meta: { otherStuffData: 1 },
                                                         }),
                       },
                       {
                         serializer:       ExampleObjectSerializerMock3,
                         root:             true,
                         meta:             { other_stuff_data: 1 },
                         transform_method: :underscore,
                         result:           JSON.generate({
                                                           data: [
                                                                   {
                                                                     name:         'Example name',
                                                                     with_example: 'An example',
                                                                   },
                                                                   {
                                                                     name:         'Example name',
                                                                     with_example: 'An example',
                                                                   },
                                                                   {
                                                                     name:         'Example name',
                                                                     with_example: 'An example',
                                                                   }
                                                                 ],
                                                           meta: { other_stuff_data: 1 },
                                                         }),
                       },
                       {
                         serializer:       ExampleObjectSerializerMock3,
                         root:             false,
                         meta:             nil,
                         message:          nil,
                         transform_method: :underscore,
                         result:           JSON.generate([
                                                           { name: 'Example name', with_example: 'An example' },
                                                           { name: 'Example name', with_example: 'An example' },
                                                           { name: 'Example name', with_example: 'An example' }
                                                         ]),
                       }
                     ]

    example_c_data.each_with_index do |example, idx|
      describe "Collection example #{idx}" do
        let(:serializer) do
          example[:serializer].new([model, model, model],
                                   root:    example[:root],
                                   meta:    example[:meta],
                                   message: example[:message])
        end

        it 'is serialized as result' do
          expect(serializer.as_json).to eq example[:result]
        end
      end
    end
  end

  context 'with inherited class' do
    let(:serializer_class) { ExampleObjectSerializerMock }
    let(:inherited_serializer_class) { InheritedExampleObjectSerializerMock }

    it 'has more attributes than base class' do
      expect(inherited_serializer_class.attributes_to_serialize.count)
        .to be > serializer_class.attributes_to_serialize.count
    end
  end
end
