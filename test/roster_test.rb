require_relative "test_helper"
require "bandcamp-discover/roster"

# Cases are real pages from the discover.bandcamp.labels similarity audit.
class RosterTest < Minitest::Test
  Roster = BandcampDiscover::Roster

  def test_a_label_credits_other_artists
    roster = Roster.new(band_name: "kranky", credits: ["Helen", "Cate Kennan", "Ana Roxanne", "Helen"])

    refute roster.solo?
    assert_equal ["Helen", "Cate Kennan", "Ana Roxanne"], roster.credits
  end

  def test_an_artist_page_credits_nobody
    roster = Roster.new(band_name: "Radiohead", credits: [nil] * 15)

    assert roster.solo?
    assert_empty roster.credits
  end

  def test_credits_naming_the_owner_are_not_a_roster
    roster = Roster.new(band_name: "Woosley", credits: ["Sean Woosley", "Woosley Band", nil, nil, nil])

    assert roster.solo?
  end

  def test_owner_match_is_case_insensitive_and_either_direction
    roster = Roster.new(band_name: "Soul Juice", credits: ["J Sand (Soul Juice)", "Geechie Dan", "soul juice"])

    assert_equal ["Geechie Dan"], roster.credits
    refute roster.solo?
  end

  def test_a_single_self_release_is_not_evidence
    roster = Roster.new(band_name: "New Label", credits: [nil])

    refute roster.solo?
  end

  def test_releases_can_outnumber_rendered_credits
    roster = Roster.new(band_name: "Whoever", credits: [], releases: 12)

    assert roster.solo?
  end

  def test_blank_band_name_keeps_every_credit
    roster = Roster.new(band_name: nil, credits: [" A ", "", "B"])

    assert_equal ["A", "B"], roster.credits
  end
end
