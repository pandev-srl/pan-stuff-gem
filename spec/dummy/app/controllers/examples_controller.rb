# frozen_string_literal: true

class ExamplesController < ApplicationController
  def example
    @resource = ExampleModel.new(name: 'Name 1', surname: 'Surname 1')

    render resource: @resource, serializer: ExampleSerializer
  end

  def example_errors
    @resource = ExampleModel.new(name: 'Name 1', surname: 'Surname 1')
    @resource.errors.add :name, message: 'Example error'

    @errors = @resource.errors

    render resource_errors: @errors
  end
end
