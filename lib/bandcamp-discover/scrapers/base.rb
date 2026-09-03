require "playwright"

module BandcampDiscover
  module Scrapers
    # Previously rescued into a puts + nil return, which made a total scraping
    # outage read as "no results" and go unnoticed.
    class ScrapeError < StandardError; end

    class Base
      def initialize(url:, browser:, max_tasks: 2)
        @url = url
        @browser = browser
        @page = browser.new_page
        @max_tasks = max_tasks
      end

      def scrape(force: false)
        guarded { yield @page if block_given? }
      end

      private

      def guarded
        yield
      rescue Playwright::TimeoutError => e
        raise ScrapeError, "Timed out waiting for an element on #{@url}: #{e.message}"
      end
    end
  end
end
