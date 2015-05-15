require 'wedge'
require 'roda'

require 'pry'
require 'awesome_print'

ROOT_PATH = File.dirname(__FILE__)

class DummyApp < Roda

  plugin :environments

  configure :development do
    require 'better_errors'

    use BetterErrors::Middleware if defined? BetterErrors
    use Rack::Static, urls: ["/public"]

    BetterErrors::Middleware.allow_ip! "0.0.0.0/0"
    BetterErrors.application_root = Dir.pwd
  end

  plugin :wedge, {
    scope: self,
    debug: true,
    plugins: [:form]
  }

  plugin :assets, {
    group_subdirs: false,
    path: ROOT_PATH,
    css_dir: '',
    js_dir: ''
  }

  route do |r|
    r.wedge_assets

    r.root do
      wedge(:root).to_js :display
    end
  end
end

Dir["#{ROOT_PATH}/forms/*.rb"].sort.each { |file| require file }
Dir["#{ROOT_PATH}/components/*.rb"].sort.each { |file| require file }
