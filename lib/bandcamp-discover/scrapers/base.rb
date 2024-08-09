require 'playwright'

module BandcampDiscover
  module Scrapers
    class Base
      def initialize(url:, browser:)
        @url = url
        @browser = browser
        @page = browser.new_page
      end

      def scrape
        yield @page if block_given?
      rescue Playwright::TimeoutError
        puts "Failed to wait for element"
      end
    end
  end
end
