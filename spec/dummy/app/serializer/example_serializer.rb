# frozen_string_literal: true

class ExampleSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :name
  attribute :surname
end
