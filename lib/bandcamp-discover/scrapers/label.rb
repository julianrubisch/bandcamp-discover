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

          band_name_location_container = page.wait_for_selector("#band-name-location")
          name = band_name_location_container.query_selector(".title").inner_text
          location = band_name_location_container.query_selector(".location").inner_text

          if bio_text&.inner_html =~ /label|platform/
            return Sync do
              music_tags = Scrapers::Music.new(url: "#{@url}/music", browser: @browser, max_tasks: @max_tasks).scrape

              puts "done scraping #{@url}"

              [@url, name, location, music_tags&.compact]
            end
          else
            puts "not a label: #{@url}"
            nil
          end
        end
      end
    end
  end
end
