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
require_relative "langsmith/run_manager"
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
    
    def run_manager
      @run_manager ||= RunManager.new(client)
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
    
    # Get the current run tree from thread-local storage
    # @return [RunTree, nil] The current run tree or nil if not in a tracing context
    def current_run_tree
      Thread.current[:langsmith_run_tree]
    end
    
    # Set the current run tree in thread-local storage
    # @param run_tree [RunTree, nil] The run tree to set as current
    # @return [RunTree, nil] The run tree that was set
    def set_current_run_tree(run_tree)
      Thread.current[:langsmith_run_tree] = run_tree
    end
    
    # Execute a block of code with tracing enabled
    # @param name [String] Name of the run
    # @param run_type [String] Type of run (e.g., "chain", "llm", "tool")
    # @param inputs [Hash] Input values for the run
    # @param tags [Array<String>] Tags to associate with the run
    # @param metadata [Hash] Metadata for the run
    # @param parent_run_id [String, nil] Parent run ID, if any
    # @param project_name [String, nil] Project name to use
    # @yield [RunTree] The run tree object for the trace
    # @return [Object] The result of the block
    def trace(name:, run_type: "chain", inputs: {}, tags: [], metadata: {}, 
             parent_run_id: nil, project_name: nil, auto_end: true, session_id: nil, reference_example_id: nil)
      # Use current run as parent if available and no parent specified
      parent = parent_run_id || (current_run_tree&.id if current_run_tree)
      
      # Create a new run tree
      run = RunTree.new(
        name: name,
        run_type: run_type,
        inputs: inputs,
        tags: tags,
        metadata: metadata,
        parent_run_id: parent,
        project_name: project_name,
        session_id: session_id,
        reference_example_id: reference_example_id
      )
      
      # Start the run
      run.post
      
      # Save the previous run to restore it later
      previous_run = current_run_tree
      
      begin
        # Set this as the current run
        set_current_run_tree(run)
        
        # Yield to the block with the run
        result = yield(run)
        
        # Automatically end the run if requested
        if auto_end
          run.end(outputs: result.is_a?(Hash) ? result : { output: result })
          run.patch
        end
        
        # Return the result
        result
      rescue StandardError => e
        # End the run with error if auto_end
        if auto_end
          run.end(error: e.message)
          run.patch
        end
        puts "Error while calling LangSmith within the SDK"
      ensure
        # Restore the previous run
        set_current_run_tree(previous_run)
      end
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
