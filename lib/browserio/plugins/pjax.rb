module BrowserIO
  module Plugins
    class Pjax < Component
      config.name :pjax, :pjax_plugin
      config.requires :history_plugin

      class Nanobar
        include Native

        alias_native :go
        alias_native :start
        alias_native :finish

        def initialize options = {}
          `var Nanobar=function(){"use strict";var t,i,e,s,h,n,o={width:"100%",height:"4px",zIndex:9999,top:"0"},a={width:0,height:"100%",clear:"both",transition:"height .3s"};return t=function(t,i){var e;for(e in i)t.style[e]=i[e];t.style["float"]="left"},s=function(){var t=this,i=this.width-this.here;.1>i&&i>-.1?(h.call(this,this.here),this.moving=!1,100==this.width&&(this.el.style.height=0,setTimeout(function(){t.cont.el.removeChild(t.el)},300))):(h.call(this,this.width-i/4),setTimeout(function(){t.go()},16))},h=function(t){this.width=t,this.el.style.width=this.width+"%"},n=function(){var t=new i(this);this.bars.unshift(t)},i=function(i){this.el=document.createElement("div"),this.el.style.backgroundColor=i.opts.bg,this.width=0,this.here=0,this.moving=!1,this.cont=i,t(this.el,a),i.el.appendChild(this.el)},i.prototype.go=function(t){t?(this.here=t,this.moving||(this.moving=!0,s.call(this))):this.moving&&s.call(this)},e=function(i){var e,s,h=this.opts=i||{};h.bg=h.bg||"#000",this.bars=[],e=this.el=document.createElement("div"),t(this.el,o),h.id&&(e.id=h.id),h.className&&(e.className=h.className),e.style.position=h.target?"relative":"fixed",h.target?(s=h.target,s.insertBefore(e,h.target.firstChild)):(s=document.getElementsByTagName("body")[0],s.appendChild(e)),s.className="nanobar-custom-parent",n.call(this)},e.prototype.go=function(t){this.bars[0].go(t),100==t&&n.call(this)},e.prototype.start=function(){(function(){var t=this.bars[0],i=function(){setTimeout(function(){var e=t.here+Math.round(10*Math.random());t.here>=99||(e>99&&(e=99),t.go(e),i())},500)};t.go(10),i()}).call(this)},e.prototype.finish=function(){this.go(100)},e}();`
          super `new Nanobar(options)`
        end
      end if client?

      def progress_bar
        $pjax_progress_bar
      end

      def get href = false
        $pjax_progress_bar = Nanobar.new({bg: '#f99f22'}.to_n)
        progress_bar.start
        `$(document).trigger('page:click')`
        $window.history.push href, pjax: true
      end

      on :click, 'a' do |el, evt|
        href = el.attr 'href'

        unless href =~ /^#/i || href =~ /^javascript:/i || el.attr('target') == '_blank'
          evt.prevent_default
          get href
        end
      end

      on :history_change do |e|
        if e.data.pjax
          progress_bar.start
          `$(document).trigger('page:request')`
          HTTP.get(e.url) do |response|
            res  = Native(response.xhr)
            html = res.responseText
            # grab and add the body
            matches = html.match(/<body[^>]*>((.|[\n\r])*)<\/body>/im)
            dom.find('body').html matches[1]
            # grab and eval the scripts
            matches = html.match(/<script>((.|[\n\r])*)<\/script>/im)
            # `eval(#{matches[0]})`
            (matches[1] || '').split('</script>').each do |script|
              # script = script.sub('<script>', '')
              script = script.strip.sub('</html>', '').sub('<script>', '')
              `jQuery.globalEval(script);`
            end
            progress_bar.finish
            `$('html, body').animate({ scrollTop: 0 }, 0); $(document).trigger('page:load');`
          end
        end
      end
    end
  end
end
