module Langsmith
  class Hub
    attr_reader :client

    def initialize(client = Langsmith.client)
      @client = client
      @api_key = client.api_key
      raise Langsmith::ConfigurationError, "API key is required" unless @api_key
    end

    # Pull a prompt from the LangSmith Hub
    # @param repo_name [String] The name of the repository to pull from
    # @param commit_hash [String, nil] The commit hash to pull from (default: latest)
    # @param include_model [Boolean] Whether to include model information in the response
    # @return [Hash] The prompt manifest
    def pull(repo_name, commit_hash: nil, include_model: false)
      # The repo_name should be just the name, like "qualify-agent"
      begin
        @client.pull_prompt(repo_name, commit_hash: commit_hash, include_model: include_model)
      rescue StandardError => e
        raise Langsmith::APIError, "Failed to pull prompt: #{e.message}"
      end
    end
    
    # Push a prompt to the LangSmith Hub
    # @param repo_name [String] The name of the repository to push to
    # @param object [Object] The prompt object to push
    # @param parent_commit_hash [String] The parent commit hash (default: "latest")
    # @param is_public [Boolean, nil] Whether the prompt should be public
    # @param description [String, nil] A description of the prompt
    # @param readme [String, nil] A readme for the prompt
    # @param tags [Array<String>, nil] Tags for the prompt
    # @return [String] The URL of the pushed prompt
    def push(repo_name, object, parent_commit_hash: "latest", is_public: nil, 
             description: nil, readme: nil, tags: nil)
      begin
        @client.push_prompt(
          repo_name, 
          object: object,
          parent_commit_hash: parent_commit_hash, 
          is_public: is_public,
          description: description,
          readme: readme,
          tags: tags
        )
      rescue StandardError => e
        raise Langsmith::APIError, "Failed to push prompt: #{e.message}"
      end
    end
  end

  class << self
    def hub
      @hub ||= Hub.new
    end
  end
end
