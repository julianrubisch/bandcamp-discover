require_relative "test_helper"
require "bandcamp-discover/scrapers/music"

# The album pages are stubbed; what is under test is how the grid's credits
# travel into the album hashes.
class MusicTest < Minitest::Test
  Music = BandcampDiscover::Scrapers::Music

  FakeBrowser = Struct.new(:pages) do
    def new_page = nil
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
end
