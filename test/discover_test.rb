require_relative "test_helper"
require "bandcamp-discover/scrapers/discover"

class DiscoverTest < Minitest::Test
  Discover = BandcampDiscover::Scrapers::Discover

  # Stub only the network, so the rest of the class runs for real.
  def build(genre: "ambient", pages: 1, batches: [])
    scraper = Discover.new(genre: genre, max_tasks: 2, pages: pages)
    queue = batches.dup
    scraper.define_singleton_method(:fetch_batch) { |_cursor| queue.shift }
    scraper
  end

  def batch(band_urls, cursor: nil)
    {
      "results" => band_urls.map { {"band_url" => _1, "item_type" => "a"} },
      "cursor" => cursor
    }
  end

  def collect(scraper)
    [].tap { |out| scraper.scrape { |url| out << url } }
  end

  def test_yields_scheme_and_host_only
    scraper = build(batches: [batch(["https://polarseasrecordings.bandcamp.com?from=discover_page"])])

    assert_equal ["https://polarseasrecordings.bandcamp.com"], collect(scraper)
  end

  def test_dedupes_labels_appearing_under_several_albums
    scraper = build(batches: [batch([
      "https://a.bandcamp.com?from=discover_page",
      "https://a.bandcamp.com?from=discover_page",
      "https://b.bandcamp.com?from=discover_page"
    ])])

    assert_equal ["https://a.bandcamp.com", "https://b.bandcamp.com"], collect(scraper).sort
  end

  def test_follows_cursor_across_pages
    scraper = build(pages: 2, batches: [
      batch(["https://a.bandcamp.com"], cursor: "next"),
      batch(["https://b.bandcamp.com"], cursor: nil)
    ])

    assert_equal ["https://a.bandcamp.com", "https://b.bandcamp.com"], collect(scraper).sort
  end

  def test_stops_early_when_cursor_is_exhausted
    scraper = build(pages: 3, batches: [
      batch(["https://a.bandcamp.com"], cursor: nil),
      batch(["https://never-reached.bandcamp.com"])
    ])

    assert_equal ["https://a.bandcamp.com"], collect(scraper)
  end

  def test_skips_unusable_band_urls
    scraper = build(batches: [batch([nil, "", "not a url", "/relative", "https://ok.bandcamp.com"])])

    assert_equal ["https://ok.bandcamp.com"], collect(scraper)
  end

  # A silent zero-result discovery is how the last breakage hid; these must raise.
  def test_raises_when_results_array_is_missing
    scraper = build(batches: [{"cursor" => "*"}])

    error = assert_raises(Discover::ResponseError) { collect(scraper) }
    assert_match(/no results array/, error.message)
  end

  def test_raises_when_results_no_longer_carry_band_url
    scraper = build(batches: [{"results" => [{"item_id" => 1, "band_name" => "x"}], "cursor" => nil}])

    error = assert_raises(Discover::ResponseError) { collect(scraper) }
    assert_match(/no band_url/, error.message)
  end

  def test_empty_results_is_not_an_error
    scraper = build(batches: [{"results" => [], "cursor" => nil}])

    assert_empty collect(scraper)
  end
end
