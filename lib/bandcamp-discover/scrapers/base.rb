require 'playwright'

module BandcampDiscover
  module Scrapers
    # Raised when a page never renders the element a scraper waits on. This used
    # to be rescued and printed, which turned a total scraping outage into a
    # single line of stdout and a nil return -- callers saw "no results" rather
    # than "broken", and the failure went unnoticed.
    class ScrapeError < StandardError; end

    class Base
      def initialize(url:, browser:, max_tasks: 2)
        @url = url
        @browser = browser
        @page = browser.new_page
        @max_tasks = max_tasks
      end

      def scrape(force: false)
        yield @page if block_given?
      rescue Playwright::TimeoutError => e
        raise ScrapeError, "Timed out waiting for an element on #{@url}: #{e.message}"
      end
    end
  end
end
