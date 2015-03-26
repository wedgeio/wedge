module BrowserIO
  class Events
    attr_accessor :scope, :browser_events, :object_events

    VIP_ORDER_LIST = %w(history_change)

    def initialize
      @browser_events = []
      @object_events  = {}
    end

    def add(*args, &block)
      event = {
        name: args.shift,
        block: block,
        options: {}
      }

      args.each do |arg|
        if arg.is_a?(String)
          event[:selector] = arg
        elsif arg.is_a? Class
          event[:klass] = arg
        else
          event[:options] = event[:options].merge(arg).indifferent.to_h
        end
      end

      if event[:name].to_s == 'ready' || event[:name] =~ /[:\s]/ || event[:selector]
        browser_events << event
      else
        event[:component] = scope.bio_opts.name

        if !scope.class.bio_opts.added_class_events && for_component = event[:options].delete(:for)
          bio_opts = BrowserIO.components[for_component].klass.bio_opts
          events = bio_opts.object_events[event.delete(:name)] ||= []
          events << event
        else
          events = object_events[event.delete(:name)] ||= []
          events << event
        end
      end
    end

    def trigger(name, options = {})
      name    = name.to_s
      options = options.indifferent

      case name
      when 'browser_events'
        # We make sure anything in the VIP_ORDER_LIST goes first
        (browser_events.sort_by do |x|
          [VIP_ORDER_LIST.index(x[:name]) || VIP_ORDER_LIST.length, browser_events.index(x)]
        end).each do |event|
          trigger_browser_event event
        end
      else
        events = object_events[name] || []
        events.each do |event|
          BrowserIO[event[:component]].instance_exec options, &event[:block]
        end
      end
    end

    def trigger_browser_event event
      comp = BrowserIO[scope.bio_opts.name]

      case event[:name]
      when 'ready'
        el = Element.find(event[:selector] != '' ? event[:selector] : 'body')

        comp.instance_exec el, &event[:block]
      when 'history_change'
        $window.history.change do |he|
          comp.instance_exec he, &event[:block]
        end
      when 'form'
        warn 'missing form class option' unless event[:klass]

        Document.on :submit, event[:selector] do |evt|
          el = evt.current_target
          evt.prevent_default

          params = {}

          # loop through all the forum values
          el.serialize_array.each do |row|
            field, _ = row

            # we need to make it native to access it like ruby
            field    = Native(field)
            name     = field['name']
            value    = field['value']

            params[name] = value
          end

          params_obj = {}

          params.each do |param, value|
            keys = param.gsub(/[^a-z0-9_]/, '|').gsub(/\|\|/, '|').gsub(/\|$/, '').split('|')
            params_obj = params_obj.deep_merge keys.reverse.inject(value) { |a, n| { n => a } }
          end

          opts[:dom] = el

          if opts && key = opts[:key]
            form = event[:klass].new params_obj[key], opts
          else
            form = event[:klass].new params_obj, opts
          end

          el.find(opts[:error_selector] || '.field-error').remove

          comp.instance_exec form, evt.current_target, evt, &event[:block]
        end
      else
        args = [event[:name]]

        if selector = event[:selector]
          args << selector
        end

        Document.on(*args) do |evt|
          el = evt.current_target
          comp.instance_exec el, evt, &event[:block]
        end

        if event[:name] =~ /ready/
          el = Element.find(event[:selector] != '' ? event[:selector] : 'body')
          comp.instance_exec el, &event[:block]
        end
      end
    end
  end
end
