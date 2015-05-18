class Wedge
  class Events
    attr_accessor :events

    VIP_ORDER_LIST = %w(history_change)

    def initialize
      @events = IndifferentHash.new
    end

    def add(wedge_name, *args, &block)
      event_name = args.shift

      events = @events[wedge_name] ||= IndifferentHash.new({
        browser_events: [],
        object_events: IndifferentHash.new,
        on_count: 0
      })

      # fix: there is a bug in opal where even though it's only including a
      # module once it is loading the class twice. So this stops on events being
      # double added
      return if events[:on_count] >= Wedge.config.component_class[wedge_name].wedge_on_count
      events[:on_count] += 1

      event = {
        name: event_name,
        block: block,
        wedge_name: wedge_name,
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

      if %w(ready history_change).include?(event[:name].to_s) || event[:name] =~ /[:\s]/ || event[:selector]
        events[:browser_events] << event
      else
        if for_component = event[:options].delete(:for)
          events = @events[for_component] ||= IndifferentHash.new({
            browser_events: [],
            object_events: IndifferentHash.new,
            on_count: 0
          })
        end

        (events[:object_events][event_name] ||= []) << event
      end
    end

    def trigger(wedge_name, event_name, *args)
      event_name = event_name.to_s

      return unless events = @events[wedge_name]

      case event_name
      when 'browser_events'
        browser_events = events[:browser_events]

        # We make sure anything in the VIP_ORDER_LIST goes first
        (browser_events.sort_by do |x|
          [VIP_ORDER_LIST.index(x[:name]) || VIP_ORDER_LIST.length, browser_events.index(x)]
        end).each do |event|
          trigger_browser_event wedge_name, event
        end
      else
        (events[:object_events][event_name] || []).each do |event|
          Wedge[event[:wedge_name]].instance_exec(*args, &event[:block])
        end
      end
    end

    def trigger_browser_event wedge_name, event
      comp = Wedge[wedge_name]

      case
      when event[:name].to_s == 'ready'
        el = Element.find(event[:selector] != '' ? event[:selector] : 'body')

        comp.instance_exec el, &event[:block]
      when event[:name].to_s == 'history_change'
        $window.history.change do |he|
          comp.instance_exec he, &event[:block]
        end
      when event[:name].to_s == 'submit' && event[:options][:form]
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

            if name =~ /\[\]$/
              name = name.gsub(/\[\]$/,'')
              params[name] = [] if params[name].nil?
              params[name].push value
            else
              params[name] = value
            end
          end

          params_obj = {}

          params.each do |param, value|
            keys = param.gsub(/[^a-z0-9_]/, '|').gsub(/\|\|/, '|').gsub(/\|$/, '').split('|')
            params_obj = params_obj.deep_merge keys.reverse.inject(value) { |a, n| { n => a } }
          end

          opts = event[:options].dup.reject { |k, v| k.to_s == 'form' }
          opts[:dom] = el

          if opts && key = opts[:key]
            form = Wedge[event[:options][:form], params_obj[key], opts]
          else
            form = Wedge[event[:options][:form], params_obj, opts]
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
