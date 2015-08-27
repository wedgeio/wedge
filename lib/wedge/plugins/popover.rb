# uses drop.js

class Wedge
  module Plugins
    class Popover < Component
      name :popover_plugin, :popover

      def display el, options = {}, &block
        return if el.data 'wedge-popover'

        el.data 'wedge-popover', true
        el = el.to_n

        options = {
          content: 'Loading...',
          position: 'right middle',
          openOn: 'hover'
        }.merge(options)

        options[:classes] = "drop-theme-arrows #{options[:classes]}"

        options = options.to_n

        opts = `$.extend(options, { target: el[0] })`
        drop = Native(`new Drop(opts)`)

        block.call(Native(opts)) if block_given?

        drop
      end

      def ajax el, options = {}, &block
        options = { content: 'loading' }.merge options
        display el, options, &block
      end
    end
  end
end
