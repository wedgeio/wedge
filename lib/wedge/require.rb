unless RUBY_ENGINE == 'opal'
  # rewrite require
  def require(name)
    Kernel.require name

    return unless defined?(Wedge) && Wedge.respond_to?(:config)

    if name[/\Awedge/] || name[Dir.pwd]
      name       = name.sub("#{Dir.pwd}/", '').gsub(/\.rb$/, '').gsub(/\//, '__')
      caller_str = "#{caller[0]}".gsub(/(#{Dir.pwd}\/|.*(?=wedge))/, '').gsub(/:.+$/, '').gsub(/\.rb$/, '').gsub(/\//, '__')

      if !caller_str['.'] && !(Wedge.config.requires[caller_str] ||= []).include?(name)
        Wedge.config.requires[caller_str] << name
      end
    end
  end

  # rewrite require_relative
  def require_relative(name)
    caller_str       = "#{caller[0]}".gsub(/:.+$/, '').gsub(/\.rb$/, '')
    caller_path_name = caller_str.gsub(%r{(#{Dir.pwd}/|.*wedge)}, '').gsub(/:.+$/, '').gsub(/^\//, '')

    path_name = caller_path_name.gsub(/(?<=\/)([^\/]*)$/, "#{name}")
    path_name = File.expand_path(path_name).sub("#{Dir.pwd}/", '') if path_name['..']
    path_name = path_name.gsub(/\//, '__')
    file      = caller_str.gsub(/(?<=\/)([^\/]*)$/, "#{name}")
    caller_path_name = caller_path_name.gsub(/\//, '__')

    if !caller_path_name['.'] && !(Wedge.config.requires[caller_path_name] ||= []).include?(path_name)
      Wedge.config.requires[caller_path_name] << path_name
    end

    Kernel.require file
  end
end
