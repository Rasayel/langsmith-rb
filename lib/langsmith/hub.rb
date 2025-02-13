module Langsmith
  class Hub
    def initialize(client = Langsmith.client)
      @client = client
      @api_key = client.api_key
      raise Langsmith::ConfigurationError, "API key is required" unless @api_key
    end

    def pull(repo_name)
      # For now, we only support fetching from the current workspace
      # The repo_name should be just the name, like "qualify-agent"
      begin
        @client.pull_prompt(repo_name)
      rescue StandardError => e
        request_info = @client.last_request_info
        raise Langsmith::APIError, "Failed to pull prompt: #{e.message}\nRequest: #{request_info}"
      end
    end
  end

  class << self
    def hub
      @hub ||= Hub.new
    end
  end
end
