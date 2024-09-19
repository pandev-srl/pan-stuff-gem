# frozen_string_literal: true

require 'spec_helper'
require 'action_controller'

RSpec.describe 'PanStuff::ResourcesControllerNotOverriddenWithServiceAndSerializer', type: :controller do
  controller do
    include PanStuff::ParamsHelpers
    include PanStuff::ResourcesController

    def resource_service_class
      ExampleResourceService
    end

    def resource_serializer
      ExampleResourceSerializer
    end
  end

  describe '#show' do
    it 'expects to raise MethodNotOverriddenError' do
      expect { get :show, params: { id: 1 } }.to raise_error PanStuff::MethodNotOverriddenError
    end
  end

  describe '#create' do
    it 'expects to raise MethodNotOverriddenError' do
      expect { post :create }.to raise_error PanStuff::MethodNotOverriddenError
    end
  end

  describe '#update' do
    it 'expects to raise MethodNotOverriddenError' do
      expect { put :update, params: { id: 1 } }.to raise_error PanStuff::MethodNotOverriddenError
    end
  end

  describe '#destroy' do
    it 'expects to raise MethodNotOverriddenError' do
      expect { delete :destroy, params: { id: 1 } }.to raise_error PanStuff::MethodNotOverriddenError
    end
  end
end
