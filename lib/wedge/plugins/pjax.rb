if RUBY_ENGINE == 'opal'
  class Element
    alias_native :mask
    alias_native :remove_data, :removeData
    alias_native :replace_with, :replaceWith
    alias_native :selectize

    def date_picker options = {}
      `self.datepicker(JSON.parse(#{options.to_json}))`
    end
  end
end

module Wedge
  module Plugins
    class Pjax < Component
      config.name :pjax, :pjax_plugin
      config.requires :history_plugin

      def get href = false
        `$(document).trigger('page:get')`
        $window.history.push href, pjax: true
      end

      on :click, 'a' do |el, evt|
        href = el.attr 'href'

        unless href =~ /^#/i || href =~ /^javascript:/i || el.attr('target') == '_blank'
          evt.prevent_default
          get href
        end
      end

      on :ready do
        %x{
          (function() {
            (function($) {
              $("<style type='text/css'>").text("#wedgePjaxLoader{-webkit-box-shadow:0 0 5px #333;-moz-box-shadow:0 0 5px #333;box-shadow:0 0 5px #333;background:#999;height:2px;position:fixed;top:0;width:50px;z-index:9999999}").appendTo("head");
              return $.fn.wedgeLoadingBar = function(options) {
                var settings;
                settings = $.extend({
                  turbolinks: true,
                  ajax: true
                }, options);
                if (settings.turbolinks) {
                  $(document).on('page:fetch', function() {
                    return window.wedgePjaxLoader.startLoader();
                  });
                  $(document).on('page:receive', function() {
                    return window.wedgePjaxLoader.sliderWidth = $('#wedgePjaxLoader').width();
                  });
                  $(document).on('page:load', function() {
                    return window.wedgePjaxLoader.restoreLoader();
                  });
                  $(document).on('page:restore', function() {
                    $('#wedgePjaxLoader').remove();
                    return window.wedgePjaxLoader.restoreLoader();
                  });
                }
                if (settings.ajax) {
                  $(document).ajaxComplete(function(e) {
                    $('#wedgePjaxLoader').remove();
                    return window.wedgePjaxLoader.restoreLoader();
                  });
                  $(document).ajaxStart(function() {
                    return window.wedgePjaxLoader.startLoader();
                  });
                }
                return window.wedgePjaxLoader = {
                  sliderWidth: 0,
                  startLoader: function() {
                    $('#wedgePjaxLoader').remove();
                    return $('<div/>', {
                      id: 'wedgePjaxLoader'
                    }).appendTo('body').animate({
                      width: $(document).width() * .4
                    }, 2000).animate({
                      width: $(document).width() * .6
                    }, 6000).animate({
                      width: $(document).width() * .90
                    }, 10000).animate({
                      width: $(document).width() * .99
                    }, 20000);
                  },
                  restoreLoader: function() {
                    return $('<div/>', {
                      id: 'wedgePjaxLoader'
                    }).css({
                      width: window.wedgePjaxLoader.sliderWidth
                    }).appendTo('body').animate({
                      width: $(document).width()
                    }, 500).fadeOut(function() {
                      return $(this).remove();
                    });
                  }
                };
              };
            })(jQuery);

          }).call(this);
        }
        `$(window).wedgeLoadingBar({turbolinks: true, ajax: false})`
      end

      on :history_change do |e|
        if e.data.pjax
          `$(document).trigger('page:fetch')`
          HTTP.get(e.url) do |response|
            `$(document).trigger('page:receive')`
            res  = Native(response.xhr)
            html = res.responseText
            # grab title
            if title = dom.find('head title')
              matches = html.match(/(<title[^>]*>)((.|[\n\r])*)<\/title>/im)
              title.text matches[2]
            end
            # grab and add the body
            matches = html.match(/(<body[^>]*>)((.|[\n\r])*)<\/body>/im)
            # grab the body attributes and set them
            attr_str = matches[1].gsub(/(^<body|>$)/, '').strip
            body = Element['<body/>']
            attr_matches = attr_str.scan(/([a-z\-]*)(?:=)((?:')[^']*(?:')|(?:")[^"]*(?:"))/im)
            attr_matches.each do |match|
              k, v = match
              body.attr(k, v.gsub(/(^("|')|("|')$)/, ''))
            end
            body.html matches[2]
            dom.find('body').replace_with body
            # grab and eval the scripts
            matches = html.match(/<script>((.|[\n\r])*)<\/script>/im)
            # `eval(#{matches[0]})`
            (matches[1] || '').split('</script>').each do |script|
              # script = script.sub('<script>', '')
              script = script.strip.sub('</html>', '').sub('<script>', '')
              `jQuery.globalEval(script);`
            end
            `$('html, body').animate({ scrollTop: 0 }, 0); $(document).trigger('page:load');`
          end
        end
      end
    end
  end
end
