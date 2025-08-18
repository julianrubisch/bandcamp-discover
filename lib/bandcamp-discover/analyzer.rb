module BandcampDiscover
  class Analyzer
    def initialize(description, model = nil)
      @description = description
      @model = model || "openrouter/auto"
    end

    def label?
      if defined?(OpenRouter) && !!OpenRouter.configuration.access_token
        response = OpenRouter::Client.new.complete(
          [
            { role: "system", content: "You are given a description that could or could not be that of a record label. Analyze and answer with true or false only. Be critical: Individuals and bands are not labels, but collectives can be labels." },
            { role: "user", content: @description }
          ],
          model: [
            @model
          ],
          extras: {
            response_format: {
              type: "json_object"
            }
          }
        )

        JSON.parse(response["choices"][0]["message"]["content"])["answer"]&.to_s&.downcase == "true"
      else
        @description.match? /label|platform|records/i
      end
    end
  end
end
