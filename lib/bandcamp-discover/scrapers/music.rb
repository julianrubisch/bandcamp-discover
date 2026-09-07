require_relative "base"
require_relative "album"
require_relative "../roster"
require "async"
require "json"
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
      #
      # Bandcamp renders the first sixteen items as HTML and ships the rest as
      # JSON in data-client-items for its own script to render after load. Read
      # both and no script has to run: the grid is complete at DOMContentLoaded.
      def grid
        guarded do
          visit(@url)
          grid = @page.wait_for_selector("#music-grid")

          rendered = grid.query_selector_all("li.music-grid-item").map do |item|
            {url: item.query_selector("a")[:href], credit: item.query_selector(".artist-override")&.inner_text}
          end

          merge_grid(rendered, grid.get_attribute("data-client-items"))
        end
      end

      # A credit is present in the JSON only when the release is not the
      # owner's; the same convention as the rendered override.
      def merge_grid(rendered, client_items_json)
        client = JSON.parse(client_items_json.to_s.empty? ? "[]" : client_items_json).map do |item|
          {url: item["page_url"], credit: item["artist"]}
        end

        (rendered + client)
          .map { |item| {url: absolute(item[:url]), credit: credit_or_nil(item[:credit])} }
          .uniq { |item| item[:url] }
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

      def credit_or_nil(credit)
        text = credit.to_s.strip
        text.empty? ? nil : text
      end
    end
  end
end
