require_relative "label"
require "net/http"
require "json"
require "uri"
require "async"
require "async/semaphore"
require "async/barrier"
require "concurrent"

module BandcampDiscover
  module Scrapers
    # Not Playwright: the /discover/<genre> grid only exists after the Vue app
    # hydrates, and Fastly serves that page a JS challenge to datacenter IPs that
    # headless Chrome never clears. The XHR behind it is unchallenged.
    #
    # It is also private and unversioned, hence assert_shape!.
    class Discover
      API_URI = URI("https://bandcamp.com/api/discover/1/discover_web")
      PAGE_SIZE = 60
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 30

      # "a" is albums, "s" is subscriptions.
      RESULT_TYPES = %w[a s].freeze

      class ResponseError < StandardError; end

      # browser: is unused, kept so existing callers do not break.
      def initialize(genre:, browser: nil, max_tasks: Concurrent.processor_count, pages: 1)
        @genre = genre
        @browser = browser
        @max_tasks = max_tasks
        @pages = pages
      end

      def scrape(force: false)
        urls = band_urls

        barrier = Async::Barrier.new

        Sync do
          semaphore = Async::Semaphore.new(@max_tasks, parent: barrier)

          urls.map do |url|
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

      private

      # One label recurs across its albums, so dedupe.
      def band_urls
        cursor = "*"
        urls = []

        @pages.times do
          body = fetch_batch(cursor)
          assert_shape!(body)

          results = body["results"]
          break if results.empty?

          urls.concat(results.map { root_url(_1["band_url"]) }.compact)

          cursor = body["cursor"]
          break if cursor.nil? || cursor.empty?
        end

        urls.uniq
      end

      def fetch_batch(cursor)
        request = Net::HTTP::Post.new(API_URI)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(
          category_id: 0,
          tag_norm_names: [@genre],
          geoname_id: 0,
          slice: "rand",
          time_facet_id: nil,
          cursor: cursor,
          size: PAGE_SIZE,
          include_result_types: RESULT_TYPES,
          followed_bands: false
        )

        response = Net::HTTP.start(
          API_URI.hostname,
          API_URI.port,
          use_ssl: true,
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT
        ) { _1.request(request) }

        unless response.is_a?(Net::HTTPSuccess)
          raise ResponseError, "discover_web returned #{response.code} for genre #{@genre.inspect}"
        end

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise ResponseError, "discover_web returned unparseable JSON for genre #{@genre.inspect}: #{e.message}"
      end

      def assert_shape!(body)
        unless body.is_a?(Hash) && body["results"].is_a?(Array)
          raise ResponseError, "discover_web response has no results array (keys: #{body.is_a?(Hash) ? body.keys.inspect : body.class})"
        end

        return if body["results"].empty? || body["results"].any? { _1.is_a?(Hash) && _1.key?("band_url") }

        raise ResponseError, "discover_web results carry no band_url (keys: #{body["results"].first.keys.inspect})"
      end

      # Strips the ?from=discover_page band_url carries.
      def root_url(band_url)
        return nil if band_url.nil? || band_url.empty?

        uri = URI.parse(band_url)
        return nil if uri.scheme.nil? || uri.host.nil?

        "#{uri.scheme}://#{uri.host}"
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
