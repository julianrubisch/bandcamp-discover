require_relative "base"
require_relative "label"
require "uri"
require "async"
require "async/semaphore"
require "async/barrier"
require "concurrent"

module BandcampDiscover
  module Scrapers
    class Discover < Base
      def initialize(genre:, browser:, max_tasks: Concurrent.processor_count)
        super(url: "https://bandcamp.com/discover/#{genre}?s=rand", browser: browser, max_tasks: max_tasks)
      end

      def scrape(force: false)
        super do |page|
          page.goto(@url)

          records_list = page.wait_for_selector("ul.items")
          records = records_list.query_selector_all("li")
          links = records.map { _1.query_selector("a")[:href] }

          # click "View more results"

          uris = links.map { ::URI.parse(_1) }

          barrier = Async::Barrier.new

          Sync do
            semaphore = Async::Semaphore.new(@max_tasks, parent: barrier)

            uris.map do |uri|
              url = "#{uri.scheme}://#{uri.host}"

              semaphore.async do
                if block_given?
                  yield url
                else
                  Scrapers::Label.new(url: url, browser: @browser).scrape
                end
              end
            end.map(&:wait).compact
          ensure
            barrier.stop
          end
        end
      end
    end
  end
end
