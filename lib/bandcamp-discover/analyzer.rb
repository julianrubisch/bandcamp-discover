require "json"
require_relative "configuration"

module BandcampDiscover
  class Analyzer
    # The model replied, but not with the object asked for. Carries the reply so
    # a failed job says what was said instead of where JSON.parse gave up.
    class NoAnswer < StandardError; end

    # A per-call model still wins over the configured one so existing callers
    # keep their behaviour.
    def initialize(description, model = nil, credits: [])
      @description = description
      @credits = credits
      @model = model || BandcampDiscover.configuration.model
    end

    def label?
      return ask(BandcampDiscover.configuration.label_prompt) if llm?

      @description.to_s.match?(/label|platform|records/i)
    end

    # The prompt says to default to false; a reply that never reached an answer
    # is that default, not a reason to lose the whole scrape.
    def accepts_demos?
      return false unless llm?

      ask(BandcampDiscover.configuration.demos_prompt)
    rescue NoAnswer
      false
    end

    private

    # open_router raises on a missing token rather than returning nil, which
    # turned the documented regex fallback into an exception.
    def llm?
      defined?(OpenRouter) && !!OpenRouter.configuration.access_token
    rescue OpenRouter::ConfigurationError
      false
    end

    def ask(prompt)
      response = OpenRouter::Client.new.complete(
        [
          {role: "system", content: prompt},
          {role: "user", content: message}
        ],
        model: [@model],
        extras: {response_format: {type: "json_object"}}
      )

      answer(response["choices"][0]["message"]["content"])["answer"]&.to_s&.downcase == "true"
    end

    # response_format is advisory on OpenRouter: Anthropic models return the
    # object inside a ```json fence, and some prepend a sentence.
    def answer(content)
      JSON.parse(content[/\{.*\}/m] || content)
    rescue JSON::ParserError
      raise NoAnswer, "model replied without a JSON object: #{content.to_s.strip[0, 200].inspect}"
    end

    # The bio alone cannot tell one person releasing under aliases from a
    # roster; who the releases are credited to is the other half of the answer.
    def message
      return @description.to_s if @credits.empty?

      "#{@description}\n\nReleases on this page are credited to #{@credits.size} " \
        "#{(@credits.size == 1) ? "artist" : "artists"} other than the page owner: #{@credits.join(", ")}."
    end
  end
end
