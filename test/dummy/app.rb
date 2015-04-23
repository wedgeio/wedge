require 'browserio'
require 'roda'

require 'pry'
require 'awesome_print'

ROOT_PATH = File.dirname(__FILE__)

class DummyApp < Roda
  plugin :browserio, {
    scope: self,
    plugins: [:form]
  }

  plugin :assets, {
    group_subdirs: false,
    path: ROOT_PATH,
    css_dir: '',
    js_dir: ''
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

BrowserIO.cache # cache files on app load
