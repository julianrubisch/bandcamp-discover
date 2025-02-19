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

      def scrape
        super do |page|
          page.goto(@url)
          album_list = page.wait_for_selector("#music-grid")
          album_links = album_list.query_selector_all("li.music-grid-item > a")

          semaphore = Async::Semaphore.new(@max_tasks)

          album_tags = album_links.take(20).map do |album_link|
            semaphore.async do
              url = "#{@base_url}#{album_link[:href]}"
              puts "starting to scrape #{url}"

              tags = Scrapers::Album.new(url: url, browser: @browser).scrape

              puts "done scraping #{url}"

              tags
            end
          end.map(&:wait)

          normalize_tally(album_tags.flatten.tally)
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
