# frozen_string_literal: true

require 'spec_helper'
require 'action_controller'

RSpec.describe 'PanStuff::ResourcesController', type: :controller do
  controller do
    include PanStuff::ParamsHelpers

    before_action do
      self.context = {
        example_data: '1',
      }
    end

    include PanStuff::ResourcesController

    def resource_service_class
      ExampleResourceService
    end

    def resource_serializer
      ExampleResourceSerializer
    end

    def resource_location
      '/example_location'
    end

    def resource_params_root_key
      :example_root_params
    end

    def create_message
      'Create message'
    end

    def update_message
      'Update message'
    end

    def destroy_message
      'Destroy message'
    end
  end

  it { expect(controller).to respond_to :index }
  it { expect(controller).to respond_to :show }
  it { expect(controller).to respond_to :create }
  it { expect(controller).to respond_to :update }
  it { expect(controller).to respond_to :destroy }

  describe '#index' do
    it 'expects to render a collection' do
      get :index

      expect(response.body).to eq JSON.generate({
                                                  data: [
                                                          { name: '1' },
                                                          { name: '2' },
                                                          { name: '3' }
                                                        ],
                                                })
    end

    it 'expects to check context' do
      get :index

      expect(controller.send(:context)).to eq({ example_data: '1' })
    end
  end

  describe '#show' do
    it 'expects to render an item' do
      get :show, params: { id: 1 }

      expect(response.body).to eq JSON.generate({
                                                  data: { name: '1' },
                                                })
    end
  end

  describe '#create' do
    context 'with valid params' do
      before do
        post :create, params: { example_root_params: { name: 1 } }, format: :json
      end

      it 'expects to render an item' do
        expect(response.body).to eq JSON.generate({
                                                    data:    { name: '1' },
                                                    message: 'Create message',
                                                  })
      end

      it { expect(response).to have_http_status :created }
    end

    context 'with invalid params' do
      before do
        post :create, params: { example_root_params: { name: nil } }, format: :json
      end

      it 'expects to render an item' do
        expect(response.body).to eq JSON.generate({
                                                    errors:  ["Name can't be blank"],
                                                    details: { name: [{ error: 'blank' }] },
                                                  })
      end

      it { expect(response).to have_http_status :unprocessable_entity }
    end

    context 'with missing root param' do
      it 'expects to raise exception' do
        expect do
          post :create, params: {}, format: :json
        end.to raise_error ActionController::ParameterMissing
      end
    end
  end

  describe '#update' do
    context 'with valid params' do
      before do
        put :update, params: { id: 1, example_root_params: { name: 1 } }, format: :json
      end

      it 'expects to render an item' do
        expect(response.body).to eq JSON.generate({
                                                    data:    { name: '1' },
                                                    message: 'Update message',
                                                  })
      end
    end

    context 'with invalid params' do
      before do
        put :update, params: { id: 1, example_root_params: { name: nil } }, format: :json
      end

      it 'expects to render errors' do
        expect(response.body).to eq JSON.generate({
                                                    errors:  ["Name can't be blank"],
                                                    details: { name: [{ error: 'blank' }] },
                                                  })
      end

      it { expect(response).to have_http_status :unprocessable_entity }
    end
  end

  describe '#destroy' do
    context 'with valid params' do
      before do
        delete :destroy, params: { id: 1 }, format: :json
      end

      it 'expects to render an item' do
        expect(response.body).to eq JSON.generate({
                                                    data:    { name: '1' },
                                                    message: 'Destroy message',
                                                  })
      end
    end

    context 'with invalid params' do
      before do
        delete :destroy, params: { id: 2 }, format: :json
      end

      it 'expects to render errors' do
        expect(response.body).to eq JSON.generate({
                                                    errors:  ["Name can't be blank"],
                                                    details: { name: [{ error: 'blank' }] },
                                                  })
      end

      it { expect(response).to have_http_status :unprocessable_entity }
    end
  end
end
