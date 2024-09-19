# frozen_string_literal: true

module PanStuff
  module Serializer
    class ValidationResponse
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Serialization

      attribute :id, type: :string
      attribute :status, type: :integer
      attribute :message, type: :string
    end
  end
end
