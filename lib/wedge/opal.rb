unless RUBY_ENGINE == 'opal'
  module Opal
    class Builder
      # @return [String] Compiled javascript.
      def javascript
        to_s
      end
    end

    def self.original_compile(source, options = {})
      Compiler.new(source, options).original_compile
    end

    class Compiler
      alias_method :original_compile, :compile
      def compile
        @result = original_compile

        if defined? Wedge
          logical_path = self.file
          classes    = Wedge.config.component_class
          comp_class = classes["#{Wedge.config.app_dir}/#{logical_path}".gsub(/\//, '__')] || classes[logical_path.gsub(/\//, '__')]

          if logical_path == 'wedge'
            compiled_data = Base64.encode64 Wedge.config.client_data.to_json
            # We need to merge in some data that is only set on the server.
            # i.e. path, assets_key etc....
            @result << Opal.original_compile("require '#{self.file}'; Wedge.config.data = HashObject.new(Wedge.config.data.to_h.merge JSON.parse(Base64.decode64('#{compiled_data}')))")
            # load all global plugins into wedge
            Wedge.config.plugins.each do |path|
              @result << Builder.build(path).to_s
            end
          elsif comp_class
            comp_class.config.on_compile.each { |blk| comp_class.instance_exec(true, &blk) }
            comp_name     = comp_class.config.name
            compiled_data = Base64.encode64 comp_class.config.client_data.to_json
            js            = ''

            js << "require '#{self.file}'; Wedge.config.component_class[:#{comp_name}].config.data = HashObject.new(Wedge.config.component_class[:#{comp_name}].config.data.to_h.merge JSON.parse(Base64.decode64('#{compiled_data}')))"
            # todo: discuss: pass plugin settings that were set server side?
            js << "; Wedge.plugin(:#{comp_name.to_s.gsub(/_plugin$/, '')})" if comp_class.config.is_plugin

            @result << Opal.original_compile(js)

            if compile_str = comp_class.config.compile_str
              @result << compile_str
            end

            load_requires logical_path
          end
        end

        @result
      end

      def load_requires path_name
        if requires = Wedge.config.requires[path_name.gsub(/\//, '__')]
          requires.each do |path|
            next unless comp_class = Wedge.config.component_class[path]

            comp_class.config.on_compile.each { |blk| comp_class.instance_eval(&blk) }

            comp_name     = comp_class.config.name
            compiled_data = Base64.encode64 comp_class.config.client_data.to_json

            load_requires path

            @result << Opal.original_compile("require '#{path}'; Wedge.config.component_class[:#{comp_name}].config.data = HashObject.new(Wedge.config.component_class[:#{comp_name}].config.data.to_h.merge JSON.parse(Base64.decode64('#{compiled_data}')))")
          end
        end
      end
    end
  end
end

class Wedge
  # Create our own opal instance.
  Opal = ::Opal.dup

  def self.version
    Wedge::VERSION
  end
end

if RUBY_ENGINE == 'opal'
  class Element
    # alias_native :mask
    alias_native :remove_data, :removeData
    alias_native :replace_with, :replaceWith
    # alias_native :selectize
  end
else
  # issue: 
  # Wedge::Opal.use_gem 'wedge'
  # NoMethodError:  method `runtime_dependencies' for nil:NilClass
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:36:in `require_paths_for_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:37:in `block in require_paths_for_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:36:in `each'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:36:in `require_paths_for_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:27:in `use_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/gems/wedge-0.1.29/lib/wedge/opal.rb:92:in `<top (required)>'
  # /home/rof/cache/bundler/ruby/2.1.0/gems/wedge-0.1.29/lib/wedge.rb:1:in `require'
  # /home/rof/cache/bundler/ruby/2.1.0/gems/wedge-0.1.29/lib/wedge.rb:1:in `<top (required)>'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/app/config/boot.rb:10:in `require'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/app/config/boot.rb:10:in `<top (required)>'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/Rakefile:15:in `require'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/Rakefile:15:in `<top (required)>'
  # (See full trace by running task with --trace)
  # make: *** [test] Error 1
  Wedge::Opal.append_path Wedge.method(:version).source_location.first.sub('wedge/opal.rb', '')
end

