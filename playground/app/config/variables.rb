Encoding.default_external = 'UTF-8'

APP_ROOT = File.expand_path '../../', __FILE__ unless defined?(APP_ROOT)
RACK_ENV = ENV.fetch('RACK_ENV') { 'development' }.freeze

# Load environment variables
%W{.env .env.#{ENV['RACK_ENV']}}.each do |file|
  file_path = "#{APP_ROOT}/../#{file}"
  File.foreach file_path do |line|
    key, value = line.split "=", 2; ENV[key] = value.gsub('\n', '').strip
  end if File.file? file_path
end if %w{development test}.include? RACK_ENV

APP_SECRET            = ENV.fetch('APP_SECRET').freeze
AWS_ACCESS_KEY_ID     = ENV.fetch('AWS_ACCESS_KEY_ID').freeze
AWS_SECRET_ACCESS_KEY = ENV.fetch('AWS_SECRET_ACCESS_KEY').freeze
AWS_BUCKET            = ENV.fetch('AWS_BUCKET').freeze
