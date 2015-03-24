module BrowserIO
  module HTML
    include Methods

    class << self
      # Parse HTML into a Nokogiri object
      # @param raw_html [String]
      # @return parsed_html [Nokogiri]
      def [](raw_html)
        return unless server?

        # remove all the starting and trailing whitespace
        raw_html = raw_html.strip

        if raw_html[/\A<!DOCTYPE/] || raw_html[/\A<html/]
          Nokogiri::HTML(raw_html)
        else
          parsed_html = Nokogiri::HTML.fragment(raw_html)

          if parsed_html.children.length >= 1
            parsed_html.children.first
          else
            parsed_html
          end
        end
      end
    end
  end
end
