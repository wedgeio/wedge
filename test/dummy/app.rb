require 'browserio'
require 'roda'

require 'pry'
require 'awesome_print'

ROOT_PATH = File.dirname(__FILE__)

class DummyApp < Roda
  plugin :assets, {
    group_subdirs: false,
    path: ROOT_PATH,
    css_dir: '',
    js_dir: '',
    js: [ 'bio/browserio.js' ]
  }

  plugin :browserio, {
    scope: self,
    assets_url: 'assets/bio',
    plugins: [:form]
  }

  route do |r|
    r.browserio

    r.root do
      bio(:root, :js).display
    end
  end
end

Dir["#{ROOT_PATH}/forms/*.rb"].sort.each { |file| require file }
Dir["#{ROOT_PATH}/components/*.rb"].sort.each { |file| require file }
