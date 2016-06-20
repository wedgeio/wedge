# Wedge

[![Join the chat at https://gitter.im/wedgeio/wedge](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/wedgeio/wedge?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Components for Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wedge'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wedge

## Basic Usage

### Setup

    class BasicComponent < Wedge::Component
      setup do |config|
        config.name :basic
      end

      def foo
        'bar'
      end
    end

### Call

    Wedge[:basic].foo

### Response

    'bar'

## Contributing

1. Fork it ( https://github.com/[my-github-username]/Wedge/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
