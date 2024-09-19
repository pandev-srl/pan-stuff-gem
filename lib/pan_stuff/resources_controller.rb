# frozen_string_literal: true

module PanStuff
  module ResourcesController
    extend ActiveSupport::Concern

    def index
      @resource_collection = resource_collection_resolver

      render resource:   @resource_collection,
             serializer: index_resource_serializer,
             context:    context,
             meta:       meta
    end

    def show
      @resource = resource_finder

      render resource:   @resource,
             serializer: show_resource_serializer,
             context:    context,
             meta:       meta,
             location:   resource_location
    end

    def create
      @resource = resource_creator

      if @resource.errors.any?
        render resource_errors: @resource.errors, status: :unprocessable_entity
      else
        render resource:   @resource,
               serializer: create_resource_serializer,
               context:    context,
               meta:       meta,
               message:    create_message,
               location:   resource_location,
               status:     :created
      end
    end

    def update
      @resource = resource_updater

      if @resource.errors.any?
        render resource_errors: @resource.errors, status: :unprocessable_entity
      else
        render resource:   @resource,
               serializer: update_resource_serializer,
               context:    context,
               meta:       meta,
               message:    update_message,
               location:   resource_location
      end
    end

    def destroy
      @resource = resource_destroyer

      if @resource.errors.any?
        render resource_errors: @resource.errors, status: :unprocessable_entity
      else
        render resource:   @resource,
               serializer: destroy_resource_serializer,
               context:    context,
               meta:       meta,
               message:    destroy_message,
               location:   resource_location
      end
    end

    protected

    def context
      @context ||= {}
    end

    def add_meta(key, value)
      meta[key] = value
    end

    def meta
      @meta ||= {}
    end

    def resource_service
      resource_service_class.new
    end

    def resource_service_class
      raise MethodNotOverriddenError.new(__method__, self)
    end

    def resource_serializer
      raise MethodNotOverriddenError.new(__method__, self)
    end

    def resource_location
      raise MethodNotOverriddenError.new(__method__, self)
    end

    def resource_params_root_key
      raise MethodNotOverriddenError.new(__method__, self)
    end

    def create_message
      nil
    end

    def update_message
      nil
    end

    def destroy_message
      nil
    end

    def resource_params
      @resource_params ||= request_params.fetch(resource_params_root_key)
    rescue KeyError => e
      raise ActionController::ParameterMissing, e
    end

    def context=(context)
      self.context.merge!(context)
    end

    def index_resource_serializer
      resource_serializer
    end

    def show_resource_serializer
      resource_serializer
    end

    def create_resource_serializer
      resource_serializer
    end

    def update_resource_serializer
      resource_serializer
    end

    def destroy_resource_serializer
      resource_serializer
    end

    def resource_collection_resolver
      resource_service.all(ancestry_key_params)
    end

    def resource_finder
      resource_service.find(ancestry_key_params, resource_key_param)
    end

    def resource_creator
      resource_service.create(ancestry_key_params, resource_create_params)
    end

    def resource_updater
      resource_service.update(ancestry_key_params, resource_key_param, resource_update_params)
    end

    def resource_destroyer
      resource_service.destroy(ancestry_key_params, resource_key_param)
    end

    def resource_key_param
      params[:id]
    end

    def ancestry_key_params
      {}
    end

    def resource_create_params
      resource_params
    end

    def resource_update_params
      resource_params
    end
  end
end
