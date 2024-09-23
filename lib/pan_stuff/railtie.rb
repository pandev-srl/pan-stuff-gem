module PanStuff
  class Railtie < ::Rails::Railtie

    initializer 'pan_stuff.setup_renderers' do
      ActionController::Renderers.add :resource do |resource, options|
        options = options.slice(:serializer, :meta, :message, :context, :message, :location)
      
        result = options[:serializer].new(resource, meta: options[:meta], message: options[:message]).as_json
      
        self.content_type = Mime[:json]
      
        result
      end
      
      ActionController::Renderers.add :resource_errors do |errors, _options|
        result = PanStuff::Serializer::ResourceErrorsSerializer.new(errors).as_json
      
        self.content_type = Mime[:json]
      
        result
      end
      
      ActionController::Renderers.add :exception do |exception, options|
        options = options.slice(:status, :error)
      
        result = PanStuff::Serializer::ExceptionSerializer.new(exception: exception, root: false, **options).as_json
      
        self.content_type = Mime[:json]
      
        result
      end

      ActiveRecord::Base.send(:include, PanStuff::ActiveRecordPagination)
    end

  end
end
