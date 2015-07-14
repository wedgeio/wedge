class Wedge
  class Railtie < ::Rails::Railtie
    initializer "request_store.insert_middleware" do |app|
      if ActionDispatch.const_defined? :RequestId
        app.config.middleware.insert_after ActionDispatch::RequestId, Wedge::Middleware
      else
        app.config.middleware.insert_after Rack::MethodOverride, Wedge::Middleware
      end

      if ActionDispatch.const_defined?(:Reloader) && ActionDispatch::Reloader.respond_to?(:to_cleanup)
        ActionDispatch::Reloader.to_cleanup do
          Wedge::Store.clear!
        end
      end
    end
  end
end
