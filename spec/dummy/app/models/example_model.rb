# frozen_string_literal: true

class ExampleModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name
  attribute :surname
end
