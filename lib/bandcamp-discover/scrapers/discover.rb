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
    # Discovery does not use Playwright.
    #
    # The /discover/<genre> HTML page is a Vue app: the server-rendered markup
    # carries only filter metadata, and the result grid (ul.items) appears only
    # after the app hydrates and issues the XHR below. Fastly bot management
    # serves that page a JS "Client Challenge" to datacenter IPs, which headless
    # Chrome does not clear, so wait_for_selector("ul.items") times out and
    # discovery silently yields nothing.
    #
    # The XHR itself is not challenged and needs no browser, cookies or auth. It
    # is a private endpoint backing Bandcamp's own frontend, though -- there is no
    # public discover API -- so the response shape is unversioned in practice and
    # can change without notice. assert_shape! exists to make that fail loudly
    # rather than quietly discovering zero labels.
    class Discover
      API_URI = URI("https://bandcamp.com/api/discover/1/discover_web")
      PAGE_SIZE = 60
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 30

      # Sent by the discover page itself; "a" is albums, "s" is subscriptions.
      RESULT_TYPES = %w[a s].freeze

      class ResponseError < StandardError; end

      # browser: is accepted but unused, so callers that still open a Playwright
      # browser for the label scrapes keep working unchanged.
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

      # Walks @pages batches via the cursor the API hands back. Labels repeat
      # across a genre (one label, many albums), so dedupe before scraping.
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

      # band_url arrives as "https://foo.bandcamp.com?from=discover_page".
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
