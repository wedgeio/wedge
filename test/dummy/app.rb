require 'browserio'
require 'roda'

require 'pry'
require 'awesome_print'

ROOT_PATH = File.dirname(__FILE__)

class DummyApp < Roda
  BrowserIO.setup do |c|
    c.scope self.new('')
    c.assets_url '/assets/bio'
  end

  def bio(*args)
    args << { scope: self }
    BrowserIO[*args]
  end

  plugin :assets, {
    group_subdirs: false,
    path: ROOT_PATH,
    css_dir: '',
    js_dir: '',
    js: [ 'bio/browserio.js' ]
  }

  route do |r|
    r.on %r{assets/bio/(.*)\.map} do |map|
      BrowserIO.source_map map
    end

    r.on %r{assets/bio/(.*)\.rb} do |component|
      if component =~ /^browserio/
        path = BrowserIO.opts.file_path.gsub(/\/browserio.rb$/, '')
        File.read("#{path}/#{component}.rb")
      else
        File.read("#{ROOT_PATH}/#{component}.rb")
      end
    end

    r.on %r{assets/bio/(.*)\.js} do |component|
      "#{BrowserIO.javascript(component)}\n//# sourceMappingURL=/assets/bio/#{component}.map"
    end

    r.root do
      bio(:root, :js).display
    end
  end
end

Dir["#{ROOT_PATH}/components/*.rb"].sort.each { |file| require file }
