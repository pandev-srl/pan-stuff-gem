# frozen_string_literal: true

require 'spec_helper'
require 'action_controller'

RSpec.describe 'PanStuff::ParamsHelpers', type: :controller do
  controller do
    include PanStuff::ParamsHelpers

    def index
      []
    end
  end

  it 'expects to normalize query params' do
    get :index, params: { exampleParam: '1' }

    expect(controller.query_params).to eq({ example_param: '1' })
  end

  it 'expects to normalize nil query params' do
    get :index, params: { exampleParam: 'null' }

    expect(controller.query_params).to eq({ example_param: nil })
  end

  it 'expects to normalize undefined query params' do
    get :index, params: { exampleParam: 'undefined' }

    expect(controller.query_params).to eq({ example_param: nil })
  end

  it 'expects to normalize ransack query params' do
    get :index, params: { q: { name_i_cont: 'null' } }

    expect(controller.query_params).to eq({ q: { name_i_cont: nil } })
  end

  it 'expects to normalize array query params' do
    get :index, params: { q: [{ name_i_cont: 'null' }] }

    expect(controller.query_params).to eq({ q: [{ name_i_cont: nil }] })
  end
end
