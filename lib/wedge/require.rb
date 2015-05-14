# unless RUBY_ENGINE == 'opal'
#   module Kernel
#     # make an alias of the original require
#     alias_method :wedge_original_require, :require
#
#     # rewrite require
#     def require(name)
#       result = wedge_original_require name
#
#       if name[/\Awedge/] || name[Dir.pwd]
#         name       = name.sub("#{Dir.pwd}/", '').gsub(/\.rb$/, '')
#         caller_str = "#{caller[0]}".gsub(/(#{Dir.pwd}\/|.*(?=wedge))/, '').gsub(/:.+$/, '').gsub(/\.rb$/, '')
#         requires   = Wedge.config.requires[caller_str] ||= []
#
#         requires << name unless requires.include? name
#       end
#
#       result
#     end
#
#     # make an alias of the original require
#     alias_method :wedge_original_require_relative, :require_relative
#
#     # rewrite require_relative
#     def require_relative(name)
#       caller_str       = "#{caller[0]}".gsub(/:.+$/, '').gsub(/\.rb$/, '')
#       caller_path_name = caller_str.gsub(%r{(#{Dir.pwd}/|.*wedge)}, '').gsub(/:.+$/, '').gsub(/^\//, '')
#
#       path_name = caller_path_name.gsub(/(?<=\/)([^\/]*)$/, "#{name}")
#       path_name = File.expand_path(path_name).sub("#{Dir.pwd}/", '') if path_name['..']
#       file      = caller_str.gsub(/(?<=\/)([^\/]*)$/, "#{name}")
#
#       requires = Wedge.config.requires[caller_path_name] ||= []
#
#       requires << path_name unless requires.include? path_name
#
#       wedge_original_require file
#     end
#   end
# end
