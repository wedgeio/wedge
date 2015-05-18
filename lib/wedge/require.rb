unless RUBY_ENGINE == 'opal'
  module Kernel
    # make an alias of the original require
    alias_method :wedge_original_require, :require

    # rewrite require
    def require(name)
      return wedge_original_require(name) unless defined?(Wedge)

      result = wedge_original_require name

      if name[/\Awedge/] || name[Dir.pwd]
        name       = name.sub("#{Dir.pwd}/", '').gsub(/\.rb$/, '').gsub(/\//, '__')
        caller_str = "#{caller[0]}".gsub(/(#{Dir.pwd}\/|.*(?=wedge))/, '').gsub(/:.+$/, '').gsub(/\.rb$/, '').gsub(/\//, '__')

        Wedge.config.requires[caller_str] << name unless (Wedge.config.requires[caller_str] ||= []).include? name
      end

      result
    end

    # make an alias of the original require
    alias_method :wedge_original_require_relative, :require_relative

    # rewrite require_relative
    def require_relative(name)
      return wedge_original_require_relative(name) unless defined?(Wedge)

      caller_str       = "#{caller[0]}".gsub(/:.+$/, '').gsub(/\.rb$/, '')
      caller_path_name = caller_str.gsub(%r{(#{Dir.pwd}/|.*wedge)}, '').gsub(/:.+$/, '').gsub(/^\//, '')

      path_name = caller_path_name.gsub(/(?<=\/)([^\/]*)$/, "#{name}")
      path_name = File.expand_path(path_name).sub("#{Dir.pwd}/", '') if path_name['..']
      path_name = path_name.gsub(/\//, '__')
      file      = caller_str.gsub(/(?<=\/)([^\/]*)$/, "#{name}")
      caller_path_name = caller_path_name.gsub(/\//, '__')

      unless caller_path_name['.'] || (Wedge.config.requires[caller_path_name] ||= []).include?(path_name)
        Wedge.config.requires[caller_path_name] << path_name
      end

      wedge_original_require file
    end
  end
end
