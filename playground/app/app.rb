class Playground
  use Rack::Session::Cookie, secret: APP_SECRET

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
    plugins: [:form],
    settings: {
      uploader: {
        aws_access_key_id: AWS_ACCESS_KEY_ID,
        aws_secret_access_key: AWS_SECRET_ACCESS_KEY,
        bucket: 'wedge'
      }
    }
  }

  plugin :assets, {
    path: "#{APP_ROOT}/../", css_dir: '', js_dir: '', group_subdirs: false,
    css: {
      default: [
        'public/vendor/normalize-css/normalize.css',
        'public/css/styles.css',
        'bower_components/fine-uploader/_build/fine-uploader.css'
      ],
    },
    js: {
      default: [
        'public/vendor/jquery/jquery.js',
        'bower_components/fine-uploader/_build/s3.jquery.fine-uploader.js'
      ],
    }
  }

  route do |r|
    r.wedge_assets
    r.assets

    r.root do
      wedge(:index).to_js :display
    end

    r.on 'uploader' do
      wedge(:uploader).to_js :display
    end
  end
end
