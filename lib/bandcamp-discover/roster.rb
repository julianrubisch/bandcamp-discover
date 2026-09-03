module BandcampDiscover
  # A label's /music grid credits each release to its artist; an artist's own
  # page credits nothing, because the artist is the page. That is the one
  # structural difference between the two, and it costs no API call.
  #
  # It only ever says "no": one person releasing under aliases looks like a
  # roster, and a bio can say "not a label" over a grid full of credits, so a
  # positive still has to come from the bio.
  class Roster
    attr_reader :band_name, :releases, :credits

    def initialize(band_name:, credits:, releases: credits.size)
      @band_name = band_name.to_s.strip
      @releases = releases
      @credits = credits.compact.map(&:strip).reject { |credit| credit.empty? || own?(credit) }.uniq
    end

    # A single self-released record is not evidence either way.
    def solo?
      credits.empty? && releases >= 2
    end

    private

    # "Sean Woosley" and "Woosley Band" on woosley.bandcamp.com are the owner,
    # not a roster.
    def own?(credit)
      a = credit.downcase
      b = band_name.downcase
      return false if b.empty?

      a.include?(b) || b.include?(a)
    end
  end
end
