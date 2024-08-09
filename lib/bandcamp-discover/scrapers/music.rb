require_relative "./base"
require_relative "./album"

module BandcampDiscover
  module Scrapers
    class Music < Base
      def initialize(url:, browser:)
        super

        uri = URI.parse(url)
        @base_url = "#{uri.scheme}://#{uri.host}"
      end

      def scrape
        super do |page|
          page.goto(@url)
          album_list = page.wait_for_selector("#music-grid")
          album_links = album_list.query_selector_all("li.music-grid-item > a")

          normalize_tally(album_links.take(20).reduce([]) do |acc, link|
            new_tags = Scrapers::Album.new(url: "#{@base_url}/#{link[:href]}", browser: @browser).scrape

            acc + new_tags
          end.tally)
        end
      end

      def normalize_tally(tally)
        total = tally.values.sum.to_f
        tally.transform_values { |count| count / total }
      end
    end
  end
end
