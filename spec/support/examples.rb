# frozen_string_literal: true

class ExampleResourceModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name

  validates :name, presence: true
end

class ExampleResourceService
  def all(_ancestry_key_params)
    [
      ExampleResourceModel.new({ name: '1' }),
      ExampleResourceModel.new({ name: '2' }),
      ExampleResourceModel.new({ name: '3' })
    ]
  end

  def find(_ancestry_key_params, _id)
    ExampleResourceModel.new({ name: '1' })
  end

  def create(_ancestry_key_params, params)
    obj = ExampleResourceModel.new(params)
    obj.valid?
    obj
  end

  def update(_ancestry_key_params, _id, params)
    obj = ExampleResourceModel.new(params)
    obj.valid?
    obj
  end

  def destroy(_ancestry_key_params, id)
    obj = case id
          when '1'
            ExampleResourceModel.new({ name: '1' })
          else
            ExampleResourceModel.new({ name: nil })
          end
    obj.valid?
    obj
  end
end

class ExampleResourceSerializer
  include PanStuff::Serializer::ObjectSerializer

  attribute :name
end
