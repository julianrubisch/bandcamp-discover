require "json"
require_relative "configuration"

module BandcampDiscover
  class Analyzer
    # A per-call model still wins over the configured one so existing callers
    # keep their behaviour.
    def initialize(description, model = nil)
      @description = description
      @model = model || BandcampDiscover.configuration.model
    end

    def label?
      return ask(BandcampDiscover.configuration.label_prompt) if llm?

      @description.to_s.match?(/label|platform|records/i)
    end

    def accepts_demos?
      return false unless llm?

      ask(BandcampDiscover.configuration.demos_prompt)
    end

    private

    def llm?
      defined?(OpenRouter) && !!OpenRouter.configuration.access_token
    end

    def ask(prompt)
      response = OpenRouter::Client.new.complete(
        [
          {role: "system", content: prompt},
          {role: "user", content: @description}
        ],
        model: [@model],
        extras: {response_format: {type: "json_object"}}
      )

      JSON.parse(response["choices"][0]["message"]["content"])["answer"]&.to_s&.downcase == "true"
    end
  end
end
