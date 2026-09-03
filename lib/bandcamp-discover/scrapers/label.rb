require_relative "base"
require_relative "music"
require_relative "../analyzer"

module BandcampDiscover
  module Scrapers
    class Label < Base
      def scrape(force: false)
        super do |page|
          puts "starting to scrape #{@url}"
          page.goto(@url)
          bio_container = page.wait_for_selector("#bio-container")
          bio_text = bio_container.query_selector("#bio-text")

          band_name_location_container = page.wait_for_selector("#band-name-location")
          name = band_name_location_container.query_selector(".title").inner_text
          location = band_name_location_container.query_selector(".location").inner_text

          music = Scrapers::Music.new(url: "#{@url}/music", browser: @browser, max_tasks: @max_tasks)
          grid = music.grid
          roster = music.roster(grid, band_name: name)

          if force || label?(roster, bio_text&.inner_html)
            return Sync do
              albums, music_tags = music.albums(grid)

              puts "done scraping #{@url}"

              {
                url: @url,
                name: name,
                location: location,
                bio: bio_text.inner_text,
                artists: roster.credits,
                tags_with_weights: music_tags&.compact,
                albums: albums
              }
            end
          else
            puts "not a label: #{@url}"
            nil
          end
        end
      end

      private

      # The grid can rule a page out for free; only the rest costs a model call.
      def label?(roster, bio)
        return false if roster.solo?

        Analyzer.new(bio, credits: roster.credits).label?
      end
    end
  end
end
