module Nokogiri
  module XML
    class NodeSet
      # fix: this is really shity
      # alias_method :original_to_html, :to_html
      # def to_html *args
      #   original_to_html(*args).gsub('%7B', "{").gsub('%7D', "}")
      # end
    end
    class Node
      # fix: this is really shity
      # alias_method :original_to_html, :to_html
      # def to_html *args
      #   original_to_html(*args).gsub('%7B', "{").gsub('%7D', "}")
      # end

      private

      alias_method :original_coerce, :coerce
      def coerce data # :nodoc:
        if data.class.to_s == 'Wedge::DOM'
          data = data.dom
        elsif data.class.to_s[/DOM$/]
          return original_coerce data
        end

        case data
        when XML::NodeSet
          return data
        when XML::DocumentFragment
          return data.children
        when String
          return fragment(data).children
        when Document, XML::Attr
          # unacceptable
        when XML::Node
          return data
        end

        raise ArgumentError, <<-EOERR
Requires a Node, NodeSet or String argument, and cannot accept a #{data.class}.
(You probably want to select a node from the Document with at() or search(), or create a new Node via Node.new().)
        EOERR
      end
    end
  end
end
