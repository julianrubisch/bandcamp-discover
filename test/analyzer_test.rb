require_relative "test_helper"
require "bandcamp-discover/analyzer"

# OpenRouter is the host app's dependency, not this gem's, so a stand-in that
# records the request is enough to prove what the Analyzer sends.
module OpenRouter
  class ConfigurationError < StandardError; end

  # The real gem raises on a missing token instead of returning nil.
  Configuration = Struct.new(:token) do
    def access_token=(value)
      self.token = value
    end

    def access_token
      token or raise ConfigurationError, "OpenRouter access token missing!"
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  class Client
    class << self
      attr_accessor :requests, :answer
    end

    def complete(messages, model:, extras:)
      self.class.requests << {messages: messages, model: model, extras: extras}
      {"choices" => [{"message" => {"content" => JSON.generate("answer" => self.class.answer)}}]}
    end
  end
end

class AnalyzerTest < Minitest::Test
  Analyzer = BandcampDiscover::Analyzer

  def setup
    BandcampDiscover.reset_configuration!
    OpenRouter.configuration.access_token = "token"
    OpenRouter::Client.requests = []
    OpenRouter::Client.answer = true
  end

  def teardown
    BandcampDiscover.reset_configuration!
    OpenRouter.configuration.access_token = nil
  end

  def test_defaults_match_the_prompts_and_model_shipped_so_far
    Analyzer.new("We release tapes.").label?

    request = OpenRouter::Client.requests.last
    assert_equal ["openrouter/auto"], request[:model]
    assert_includes request[:messages].first[:content], "Individuals and bands are not labels"
    assert_equal "We release tapes.", request[:messages].last[:content]
  end

  def test_configured_prompt_and_model_are_sent
    BandcampDiscover.configure do |config|
      config.model = "anthropic/claude-3.5-haiku"
      config.label_prompt = "Is this a label? Answer {\"answer\": true|false}."
    end

    Analyzer.new("bio").label?

    request = OpenRouter::Client.requests.last
    assert_equal ["anthropic/claude-3.5-haiku"], request[:model]
    assert_equal "Is this a label? Answer {\"answer\": true|false}.", request[:messages].first[:content]
  end

  def test_per_call_model_wins_over_the_configured_one
    BandcampDiscover.configure { |config| config.model = "configured/model" }

    Analyzer.new("bio", "explicit/model").label?

    assert_equal ["explicit/model"], OpenRouter::Client.requests.last[:model]
  end

  def test_demos_prompt_is_configurable_too
    BandcampDiscover.configure { |config| config.demos_prompt = "Demos?" }

    Analyzer.new("bio").accepts_demos?

    assert_equal "Demos?", OpenRouter::Client.requests.last[:messages].first[:content]
  end

  def test_credits_are_appended_to_the_bio
    Analyzer.new("We run a tape label.", credits: ["Helen", "Cate Kennan"]).label?

    message = OpenRouter::Client.requests.last[:messages].last[:content]
    assert_equal "We run a tape label.\n\nReleases on this page are credited to 2 artists other than the page owner: Helen, Cate Kennan.", message
  end

  def test_no_credits_sends_the_bio_alone
    Analyzer.new(nil, credits: []).label?

    assert_equal "", OpenRouter::Client.requests.last[:messages].last[:content]
  end

  def test_parses_the_answer
    OpenRouter::Client.answer = false

    refute Analyzer.new("bio").label?
  end

  def test_falls_back_to_the_regex_without_a_token
    OpenRouter.configuration.access_token = nil

    assert Analyzer.new("An independent label from Graz").label?
    refute Analyzer.new("Solo musician").label?
    refute Analyzer.new(nil).label?
    refute Analyzer.new("Send demos to ...").accepts_demos?
    assert_empty OpenRouter::Client.requests
  end
end
