# frozen_string_literal: true

class ExampleEntity < ApplicationRecord
  has_many :related_objects
end
