require "playwright"

module BandcampDiscover
  module Scrapers
    # Previously rescued into a puts + nil return, which made a total scraping
    # outage read as "no results" and go unnoticed.
    class ScrapeError < StandardError; end

    class Base
      # Nothing read from a page is an image, a player or a font, and the
      # album pages are twenty per label; not fetching them is most of the
      # time and bandwidth a scrape used to cost.
      BLOCKED_RESOURCES = %w[image media font].freeze

      def initialize(url:, browser:, max_tasks: 2)
        @url = url
        @browser = browser
        @page = browser.new_page
        @page.route("**/*", ->(route, request) { BLOCKED_RESOURCES.include?(request.resource_type) ? route.abort : route.continue })
        @max_tasks = max_tasks
      end

      def scrape(force: false)
        guarded { yield @page if block_given? }
      end

      private

      # Everything read is in the server-rendered HTML, so the DOM is enough;
      # waiting for "load" waited on every tracker and player asset, and one
      # slow one failed the whole label.
      def visit(url)
        @page.goto(url, waitUntil: "domcontentloaded")
      end

      def guarded
        yield
      rescue Playwright::TimeoutError => e
        raise ScrapeError, "Timed out waiting for an element on #{@url}: #{e.message}"
      end
    end
  end
end
