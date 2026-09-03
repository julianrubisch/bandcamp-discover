module BandcampDiscover
  # The prompts decide what enters a catalogue, and tuning them used to mean a
  # gem release. Hosting apps set them once; the defaults keep every existing
  # caller behaving as before.
  class Configuration
    DEFAULT_MODEL = "openrouter/auto"

    DEFAULT_LABEL_PROMPT = "You are given a description that could or could not be that of a record label. " \
      "Analyze and answer with a JSON object {\"answer\": true|false}. " \
      "Be critical: Individuals and bands are not labels, but collectives can be labels."

    DEFAULT_DEMOS_PROMPT = "You are given a description of a record label or music platform. " \
      "Analyze if they accept demo submissions from artists. Look for mentions of 'demos', 'demo submissions', " \
      "'send demos', 'submit music', 'accepting submissions', contact information for demos, or similar language. " \
      "Be critical, and default to false. Only answer with true when you are certain that the label accepts demos. " \
      "Answer with a JSON object {\"answer\": true|false}."

    attr_accessor :model, :label_prompt, :demos_prompt

    def initialize
      @model = DEFAULT_MODEL
      @label_prompt = DEFAULT_LABEL_PROMPT
      @demos_prompt = DEFAULT_DEMOS_PROMPT
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = nil
    end
  end
end
