# frozen_string_literal: true

require 'spec_helper'
require 'action_controller'

RSpec.describe 'ActiveSupport::Renderers', type: :controller do
  controller do
    include AbstractController::Rendering
    include ActionController::Rendering
    include ActionController::Renderers

    def renders_exception
      exception = StandardError.new('An example error')
      render exception: exception.message, status: 500, error: 'Internal server error'
    end
  end

  before do
    routes.draw do
      get 'renders_exception', action: :renders_exception, controller: :anonymous
    end
  end

  it 'expects to render an exception' do
    get :renders_exception

    expect(response.body).to eq JSON.generate(
      {
        status:    500,
        error:     'Internal server error',
        exception: 'An example error',
      }
    )
  end

  it 'expects to have http status 500' do
    get :renders_exception

    expect(response).to have_http_status :internal_server_error
  end
end
