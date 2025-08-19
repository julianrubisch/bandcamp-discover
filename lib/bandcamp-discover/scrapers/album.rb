require_relative "./base"
require_relative "./music"

module BandcampDiscover
  module Scrapers
    class Album < Base
      def scrape(force: false)
        super do |page|
          page.goto(@url)

          title = page.query_selector("meta[name=title]")[:content]

          # querying all tags in the bottom and returning their text node
          tags = page.query_selector_all("a.tag")
          tags.map!(&:inner_text)

          player = page.query_selector("meta[property='og:video']")[:content]

          [@url, title, tags, player]
        end
      end
    end
  end
end
