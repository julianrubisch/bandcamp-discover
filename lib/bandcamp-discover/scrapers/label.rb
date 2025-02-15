require_relative "./base"
require_relative "./music"

module BandcampDiscover
  module Scrapers
    class Label < Base
      def scrape
        super do |page|
          puts "starting to scrape #{@url}"
          page.goto(@url)
          bio_container = page.wait_for_selector("#bio-container")
          bio_text = bio_container.query_selector("#bio-text")
          if bio_text&.inner_html =~ /label|platform/
            return Sync do
              [@url, Scrapers::Music.new(url: "#{@url}/music", browser: @browser).scrape]
            end
          end
        end
      end
    end
  end
end
