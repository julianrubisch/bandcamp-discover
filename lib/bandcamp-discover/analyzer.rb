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
            { role: "system", content: "You are given a description that could or could not be that of a record label. Analyze and answer witha JSON object  {\"answer\": true|false}. Be critical: Individuals and bands are not labels, but collectives can be labels." },
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

    def accepts_demos?
      if defined?(OpenRouter) && !!OpenRouter.configuration.access_token
        response = OpenRouter::Client.new.complete(
          [
            { role: "system", content: "You are given a description of a record label or music platform. Analyze if they accept demo submissions from artists. Look for mentions of 'demos', 'demo submissions', 'send demos', 'submit music', 'accepting submissions', contact information for demos, or similar language. Be critical, and default to false. Only answer with true when you are certain that the label accepts demos. Answer with a JSON object {\"answer\": true|false}." },
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
        false
      end
    end
  end
end
