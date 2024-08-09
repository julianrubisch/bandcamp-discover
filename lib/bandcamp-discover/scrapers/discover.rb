require_relative "./base"
require_relative "./label"
require "uri"

module BandcampDiscover
  module Scrapers
    class Discover < Base
      def initialize(genre:, browser:)
        super(url: "https://bandcamp.com/discover/#{genre}?s=rand", browser: browser)
      end

      def scrape
        super do |page|
          page.goto(@url)

          records_list = page.wait_for_selector("ul.items")
          records = records_list.query_selector_all("li")
          links = records.map { _1.query_selector("a")[:href] }

          # click "View more results"

          uris = links.map { ::URI.parse(_1) }

          uris.map do |uri|
            url = "#{uri.scheme}://#{uri.host}"
            Scrapers::Label.new(url: url, browser: @browser).scrape
          end.compact
        end
      end
    end
  end
end
