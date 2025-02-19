require 'playwright'

module BandcampDiscover
  module Scrapers
    class Base
      def initialize(url:, browser:, max_tasks: 2)
        @url = url
        @browser = browser
        @page = browser.new_page
        @max_tasks = max_tasks
      end

      def scrape
        yield @page if block_given?
      rescue Playwright::TimeoutError
        puts "Failed to wait for element"
      end
    end
  end
end
