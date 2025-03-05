require "zeitwerk"
require "json"

# Require error classes first
require_relative "langsmith/errors"
require_relative "langsmith/traceable"
require_relative "langsmith/models/base_model"
require_relative "langsmith/models/message_template"
require_relative "langsmith/models/prompt_template"
require_relative "langsmith/models/model"
require_relative "langsmith/models/tool"
require_relative "langsmith/models/chat_prompt_template"
require_relative "langsmith/models/prompt"
require_relative "langsmith/client"
require_relative "langsmith/hub"
require_relative "langsmith/run_tree"
require_relative "langsmith/chat"
require_relative "langsmith/wrappers/openai"
require_relative "langsmith/wrappers/anthropic"
require_relative "langsmith/wrappers/cohere"

module Langsmith
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def client
      @client ||= Client.new(
        api_key: configuration&.api_key,
        api_url: configuration&.api_url
      )
    end

    def hub
      @hub ||= Hub.new(client)
    end

    def wrap_openai(client = nil, **options)
      Wrappers::OpenAI.new(client, **options)
    end

    def wrap_anthropic(client = nil, **options)
      Wrappers::Anthropic.new(client, **options)
    end

    def wrap_cohere(client = nil, **options)
      Wrappers::Cohere.new(client, **options)
    end

    def prompt(prompt_name, include_model: false)
      Models::Prompt.pull(prompt_name, include_model: include_model)
    end
  end

  class Configuration
    attr_accessor :api_key, :api_url, :project_name

    def initialize
      @api_url = ENV["LANGSMITH_ENDPOINT"] || "https://api.smith.langchain.com"
      @api_key = ENV["LANGCHAIN_API_KEY"]
      @project_name = ENV["LANGCHAIN_PROJECT"] || "default"
    end
  end
end

# Set up autoloading
loader = Zeitwerk::Loader.for_gem
loader.push_dir(File.expand_path("../", __FILE__))
loader.inflector.inflect(
  "openai" => "OpenAI",
  "ai_message_template" => "AIMessageTemplate"
)
loader.setup
