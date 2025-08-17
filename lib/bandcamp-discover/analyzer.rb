module BandcampDiscover
  class Analyzer
    def initialize(description)
      @description = description
    end

    def label?
      if defined?(OpenRouter) && !!ENV["OPENROUTER_API_KEY"]
      else
        @description =~ /label|platform|records/i
      end
    end
  end
end
