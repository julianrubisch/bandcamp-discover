require_relative "base"
require_relative "album"
require "async"
require "async/semaphore"

module BandcampDiscover
  module Scrapers
    class Music < Base
      def initialize(url:, browser:, max_tasks:)
        super

        uri = URI.parse(url)
        @base_url = "#{uri.scheme}://#{uri.host}"
      end

      def scrape(force: false)
        super do |page|
          page.goto(@url)
          album_list = page.wait_for_selector("#music-grid")
          album_links = album_list.query_selector_all("li.music-grid-item > a")

          semaphore = Async::Semaphore.new(@max_tasks)

          albums = album_links.take(20).map do |album_link|
            semaphore.async do
              url = album_link[:href].start_with?("https://") ? album_link[:href] : "#{@base_url}#{album_link[:href]}"
              puts "starting to scrape #{url}"

              album = Scrapers::Album.new(url: url, browser: @browser).scrape

              puts "done scraping #{url}"

              album
            end
          end.map(&:wait)

          albums.map! do |album_url, album_title, album_tags, album_player|
            { url: album_url, title: album_title, tags: album_tags, player_url: album_player }
          end

          [albums, normalize_tally(albums.map { _1[:tags] }.flatten.tally)]
        end
      end

      def normalize_tally(tally)
        total = tally.values.sum.to_f
        tally.transform_values! { |count| count / total }
        tally.sort_by { |k, v| v }.reverse.to_h
      end
    end
  end
end
