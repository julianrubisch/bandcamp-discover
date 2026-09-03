require_relative "base"
require_relative "album"
require_relative "../roster"
require "async"
require "async/semaphore"

module BandcampDiscover
  module Scrapers
    class Music < Base
      MAX_ALBUMS = 20

      def initialize(url:, browser:, max_tasks:)
        super

        uri = URI.parse(url)
        @base_url = "#{uri.scheme}://#{uri.host}"
      end

      def scrape(force: false)
        albums(grid)
      end

      # The grid alone tells a label from an artist (see Roster), and it is one
      # page load against the twenty behind albums, so callers can look at it
      # before paying for the rest.
      def grid
        guarded do
          @page.goto(@url)
          items = @page.wait_for_selector("#music-grid").query_selector_all("li.music-grid-item")

          items.map do |item|
            {
              url: absolute(item.query_selector("a")[:href]),
              credit: item.query_selector(".artist-override")&.inner_text&.strip
            }
          end
        end
      end

      def roster(grid, band_name:)
        Roster.new(band_name: band_name, credits: grid.map { _1[:credit] }, releases: grid.size)
      end

      # Each album carries the credit its grid item showed: the artist's name,
      # or nil when the release is credited to the page owner. The grid is the
      # only place the credit appears without another page load.
      def albums(grid)
        guarded do
          semaphore = Async::Semaphore.new(@max_tasks)

          albums = grid.take(MAX_ALBUMS).map do |item|
            semaphore.async do
              puts "starting to scrape #{item[:url]}"

              album = Scrapers::Album.new(url: item[:url], browser: @browser).scrape

              puts "done scraping #{item[:url]}"

              [item, album]
            end
          end.map(&:wait)

          albums.map! do |item, (album_url, album_title, album_tags, album_player)|
            {url: album_url, title: album_title, tags: album_tags, player_url: album_player, artist: item[:credit]}
          end

          [albums, normalize_tally(albums.map { _1[:tags] }.flatten.tally)]
        end
      end

      def normalize_tally(tally)
        total = tally.values.sum.to_f
        tally.transform_values! { |count| count / total }
        tally.sort_by { |k, v| v }.reverse.to_h
      end

      private

      def absolute(href)
        href.start_with?("https://") ? href : "#{@base_url}#{href}"
      end
    end
  end
end
