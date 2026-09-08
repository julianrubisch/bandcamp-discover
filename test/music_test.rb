require_relative "test_helper"
require "bandcamp-discover/scrapers/music"

# The album pages are stubbed; what is under test is how the grid's credits
# travel into the album hashes.
class MusicTest < Minitest::Test
  Music = BandcampDiscover::Scrapers::Music

  FakePage = Struct.new(:routes) do
    def route(pattern, handler) = (self.routes ||= []) << pattern
  end

  FakeBrowser = Struct.new(:pages) do
    def new_page = FakePage.new
  end

  FakeAlbum = Struct.new(:url) do
    def scrape = [url, "Title of #{url}", ["drone"], nil]
  end

  def setup
    @music = Music.new(url: "https://kranky.bandcamp.com/music", browser: FakeBrowser.new, max_tasks: 2)
  end

  def test_each_album_carries_the_credit_from_its_grid_item
    grid = [
      {url: "https://kranky.bandcamp.com/album/one", credit: "Helen"},
      {url: "https://kranky.bandcamp.com/album/two", credit: nil}
    ]

    albums, tags = BandcampDiscover::Scrapers::Album.stub(:new, ->(url:, **) { FakeAlbum.new(url) }) do
      Sync { @music.albums(grid) }
    end

    assert_equal ["Helen", nil], albums.map { _1[:artist] }
    assert_equal ["https://kranky.bandcamp.com/album/one", "https://kranky.bandcamp.com/album/two"], albums.map { _1[:url] }
    assert_equal({"drone" => 1.0}, tags)
  end

  def test_a_timed_out_album_still_keeps_its_credit
    grid = [{url: "https://kranky.bandcamp.com/album/gone", credit: "Helen"}]
    timed_out = Struct.new(:url) { def scrape = nil }

    albums, _tags = BandcampDiscover::Scrapers::Album.stub(:new, ->(url:, **) { timed_out.new(url) }) do
      Sync { @music.albums(grid) }
    end

    assert_equal [{url: nil, title: nil, tags: nil, player_url: nil, artist: "Helen"}], albums
  end

  # Bandcamp renders sixteen items and ships the rest as JSON for its own
  # script; reading both makes the grid complete without running it.
  def test_grid_merges_rendered_items_with_the_client_items_json
    rendered = [
      {url: "/album/overflowing", credit: " Early Moon "},
      {url: "/album/own-release", credit: nil}
    ]
    json = '[{"art_id":1,"artist":"David Cordero","band_id":3141249859,"id":2,"page_url":"/album/and-stillness-came","title":"And Stillness Came","type":"album"},' \
           '{"art_id":3,"band_id":3141249859,"id":4,"page_url":"/track/pay","title":"Pay","type":"track"},' \
           '{"art_id":5,"artist":"","band_id":3141249859,"id":6,"page_url":"/album/overflowing","title":"dup","type":"album"}]'

    grid = @music.merge_grid(rendered, json)

    assert_equal [
      {url: "https://kranky.bandcamp.com/album/overflowing", credit: "Early Moon"},
      {url: "https://kranky.bandcamp.com/album/own-release", credit: nil},
      {url: "https://kranky.bandcamp.com/album/and-stillness-came", credit: "David Cordero"},
      {url: "https://kranky.bandcamp.com/track/pay", credit: nil}
    ], grid
  end

  def test_grid_without_client_items_is_the_rendered_items
    rendered = [{url: "https://radiohead.bandcamp.com/album/kid-a-mnesia", credit: nil}]

    assert_equal rendered, @music.merge_grid(rendered, nil)
    assert_equal rendered, @music.merge_grid(rendered, "")
  end

  def test_pages_block_images_media_and_fonts
    page = @music.instance_variable_get(:@page)

    assert_equal ["**/*"], page.routes
    assert_equal %w[image media font], BandcampDiscover::Scrapers::Base::BLOCKED_RESOURCES
  end
end
