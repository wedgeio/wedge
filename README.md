# BrowserIO

Components for Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'browserio'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install browserio

## Basic Usage

### Setup

    class BasicComponent < BrowserIO::Component
      setup do |config|
        config.name :basic
      end

      def foo
        'bar'
      end
    end

### Call

    Browser[:basic].foo

### Response

    'bar'

## Contributing

1. Fork it ( https://github.com/[my-github-username]/BrowserIO/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
