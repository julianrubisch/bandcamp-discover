require_relative "./base"
require_relative "./music"

module BandcampDiscover
  module Scrapers
    class Album < Base
      def scrape(force: false)
        super do |page|
          page.goto(@url)

          # querying all tags in the bottom and returning their text node
          tags = page.query_selector_all("a.tag")
          tags.map { _1.inner_text }
        end
      end
    end
  end
end
