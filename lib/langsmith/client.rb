require "securerandom"
require "net/http"
require "uri"
require "json"
require "time"

module Langsmith
  class Client
    attr_reader :api_url, :api_key, :tenant_id

    def initialize(api_url:, api_key:, tenant_id: nil)
      @api_url = api_url
      @api_key = api_key
      @tenant_id = tenant_id || ENV["LANGSMITH_TENANT_ID"]
      raise Langsmith::ConfigurationError, "API key is required" unless @api_key
    end

    # Make an HTTP request to the LangSmith API
    def request(method, path, params = {}, body = nil)
      uri = URI.join(api_url, path)
      
      # Add query parameters to URI if present
      uri.query = URI.encode_www_form(params) if params && !params.empty?
      
      # Create the request object based on the HTTP method
      request = case method.to_s.downcase
      when 'get'
        Net::HTTP::Get.new(uri)
      when 'post'
        req = Net::HTTP::Post.new(uri)
        req.body = body.to_json if body
        req
      when 'patch'
        req = Net::HTTP::Patch.new(uri)
        req.body = body.to_json if body
        req
      when 'delete'
        Net::HTTP::Delete.new(uri)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
      
      # Set headers
      request["x-api-key"] = api_key
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      
      # Send the request
      begin
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end
        
        # Parse and handle the response
        if response.is_a?(Net::HTTPSuccess)
          JSON.parse(response.body) rescue response.body
        else
          raise Langsmith::APIError.new("API request failed with status #{response.code}: #{response.body}")
        end
      rescue => e
        raise Langsmith::APIError.new("API request failed: #{e.message}")
      end
    end

    def create_run(
      name:,
      run_type: nil,
      inputs: {},
      run_id: nil,
      tags: [],
      metadata: {},
      parent_run_id: nil,
      project_name: nil,
      start_time: nil,
      end_time: nil,
      status: "started",
      extra: nil,
      reference_example_id: nil,
      session_id: nil
    )
      run_id ||= SecureRandom.uuid
      project_name ||= Langsmith.configuration.project_name

      # If session_id is provided, ensure it's in metadata
      metadata = metadata.dup
      metadata["session_id"] = session_id if session_id
      
      body = {
        id: run_id,
        name: name,
        run_type: run_type,
        inputs: inputs,
        tags: tags,
        metadata: metadata,
        parent_run_id: parent_run_id,
        project_name: project_name,
        start_time: start_time&.iso8601,
        end_time: end_time&.iso8601,
        status: status,
        reference_example_id: reference_example_id
      }.compact

      # Only add extra if it's explicitly provided
      body[:extra] = extra unless extra.nil?

      begin
        request(:post, "api/v1/runs", {}, body)
      rescue StandardError => e
        request_info = "POST #{api_url}/api/v1/runs\nBody: #{body.inspect}"
        raise Langsmith::APIError, "Failed to create run: #{e.message}\nRequest: #{request_info}"
      end
    end

    def update_run(
      run_id:,
      end_time: nil,
      error: nil,
      inputs: nil,
      outputs: nil,
      metadata: nil,
      status: nil,
      parent_run_id: nil,
      reference_example_id: nil,
      feedback_stats: nil,
      session_id: nil
    )
      # Convert end_time to ISO8601 if it's a Time object
      formatted_end_time = case end_time
      when Time
        end_time.iso8601
      when String
        # Try to parse it to ensure it's a valid timestamp
        Time.parse(end_time).iso8601
      when nil
        nil
      else
        raise Langsmith::ArgumentError, "end_time must be a Time object or a valid timestamp string"
      end

      body = {
        end_time: formatted_end_time,
        error: error,
        inputs: inputs,
        outputs: outputs,
        metadata: metadata,
        status: status,
        parent_run_id: parent_run_id,
        reference_example_id: reference_example_id,
        feedback_stats: feedback_stats,
        session_id: session_id
      }.compact

      begin
        request(:patch, "api/v1/runs/#{run_id}", {}, body)
      rescue StandardError => e
        request_info = "PATCH #{api_url}/api/v1/runs/#{run_id}\nBody: #{body.inspect}"
        raise Langsmith::APIError, "Failed to update run: #{e.message}\nRequest: #{request_info}"
      end
    end

    def get_run(run_id:)
      begin
        request(:get, "api/v1/runs/#{run_id}")
      rescue StandardError => e
        request_info = "GET #{api_url}/api/v1/runs/#{run_id}"
        raise Langsmith::APIError, "Failed to get run: #{e.message}\nRequest: #{request_info}"
      end
    end

    # Pull a prompt from LangChain Hub
    def pull_prompt(repo_name, commit_hash: nil, include_model: false)
      # First get the repo details using the current workspace (-)
      if commit_hash.nil?
        repo_data = request(:get, "api/v1/repos/-/#{repo_name}")["repo"] 
        commit_hash = repo_data["last_commit_hash"] 
      end
      commit_data = request(:get, "api/v1/commits/-/#{repo_name}/#{commit_hash}", { include_model: include_model })

      # Return the manifest from the commit data
      commit_data["manifest"]
    rescue StandardError => e
      request_info = "GET #{api_url}/api/v1/repos/-/#{repo_name} or GET #{api_url}/api/v1/commits/-/#{repo_name}/..."
      raise Langsmith::APIError, "Failed to pull prompt: #{e.message}\nRequest: #{request_info}"
    end
    
    # Push a prompt to LangChain Hub
    # @param repo_name [String] The name of the repository to push to
    # @param object [Object] The prompt object to push
    # @param parent_commit_hash [String] The parent commit hash (default: "latest")
    # @param is_public [Boolean, nil] Whether the prompt should be public
    # @param description [String, nil] A description of the prompt
    # @param readme [String, nil] A readme for the prompt
    # @param tags [Array<String>, nil] Tags for the prompt
    # @return [String] The URL of the pushed prompt
    def push_prompt(repo_name, object: nil, parent_commit_hash: "latest", is_public: nil, 
                   description: nil, readme: nil, tags: nil)
      # Prepare the prompt data
      prompt_data = {}
      
      # Add object data if present (this would be a prompt template, model, etc.)
      if object
        # If it's a ChatPromptTemplate or Prompt, convert it to a proper format
        if object.is_a?(Langsmith::Models::BaseModel)
          prompt_data[:manifest] = object.as_json
        else
          prompt_data[:manifest] = object
        end
      end
      
      # Add metadata
      prompt_data[:description] = description if description
      prompt_data[:readme] = readme if readme
      prompt_data[:is_public] = is_public unless is_public.nil?
      prompt_data[:tags] = tags if tags
      
      # Make the API request
      if parent_commit_hash == "latest"
        # Get the latest commit hash first
        repo_data = request(:get, "api/v1/repos/-/#{repo_name}")["repo"] rescue nil
        parent_commit_hash = repo_data["last_commit_hash"] if repo_data
      end
      
      # If no commit hash found, this is a new repo
      endpoint = if parent_commit_hash && parent_commit_hash != "latest"
        "api/v1/commits/-/#{repo_name}/#{parent_commit_hash}"
      else
        "api/v1/repos/-/#{repo_name}"
      end
      
      response = request(:post, endpoint, {}, prompt_data)
      
      # Return the URL to the prompt in LangSmith
      "#{api_url.chomp('/')}/p/#{response['repo']['owner']}/#{response['repo']['name']}/#{response['commit']['sha']}"
    rescue StandardError => e
      request_info = "POST #{api_url}/#{endpoint}\nBody: #{prompt_data.inspect}"
      raise Langsmith::APIError, "Failed to push prompt: #{e.message}\nRequest: #{request_info}"
    end

    # List runs with advanced filtering
    # @param project_name [String, nil] Project to filter by
    # @param parent_run_id [String, nil] Parent run ID to filter by
    # @param trace_id [String, nil] Trace ID to filter by
    # @param run_type [String, nil] Run type to filter by
    # @param session_id [String, Array<String>, nil] Session ID(s) to filter by
    # @param filter_tags [Array<String>, nil] Tags to filter by
    # @param run_name [String, nil] Run name to filter by
    # @param start_time [Time, nil] Start time for filtering
    # @param end_time [Time, nil] End time for filtering
    # @param limit [Integer] Maximum number of runs to return
    # @param offset [Integer] Offset for pagination
    # @return [Array<Hash>] Array of run objects
    def list_runs(
      project_name: nil,
      parent_run_id: nil,
      trace_id: nil,
      run_type: nil,
      session_id: nil,
      filter_tags: nil,
      run_name: nil,
      start_time: nil,
      end_time: nil,
      limit: 50,
      offset: 0
    )
      project = project_name || Langsmith.configuration.project_name
      
      # Build query body
      body = {
        project_name: project,
        limit: limit,
        offset: offset
      }.compact
      
      # Add only valid identifiers
      body[:parent_run_id] = parent_run_id if parent_run_id
      body[:trace_id] = trace_id if trace_id
      body[:run_type] = run_type if run_type
      body[:run_name] = run_name if run_name
      body[:start_time] = start_time if start_time
      body[:end_time] = end_time if end_time
      
      # Add session_id according to API requirements - must be valid UUIDs
      if session_id && session_id != "*" && session_id != ["*"]
        if session_id.is_a?(Array)
          body[:session] = session_id.compact.reject { |id| id == "*" }
        else
          body[:session] = [session_id]
        end
        
        # Only add if we have valid session IDs
        body.delete(:session) if body[:session].empty?
      end
      
      # Handle tags according to API format
      if filter_tags && !filter_tags.empty?
        body[:filter] = { tags: filter_tags }.to_json
      end
      
      begin
        request(:post, "api/v1/runs/query", {}, body)
      rescue StandardError => e
        request_info = "POST #{api_url}/api/v1/runs/query\nBody: #{body.inspect}"
        
        error_msg = "Failed to list runs: #{e.message}"
        
        # Add helpful message for common errors
        if e.message.include?("session") && e.message.include?("UUID") 
          error_msg += "\n\nNOTE: The LangSmith API requires at least one of these parameters with valid values:" +
                      "\n- parent_run_id: A valid run ID" +
                      "\n- trace_id: A valid trace ID" + 
                      "\n- session_id: A valid UUID or array of UUIDs" +
                      "\n\nWildcards like '*' are not supported. For a valid session_id, use an actual thread_id."
        elsif e.message.include?("One or more sessions not found")
          error_msg += "\n\nNOTE: The session ID provided does not exist in LangSmith. This can happen if:" +
                      "\n- The thread_id hasn't been synchronized with LangSmith yet" +
                      "\n- The thread exists in a different project" +
                      "\n- The thread has been deleted" +
                      "\n\nTry using parent_run_id instead or query by project with filter_tags."
        end
        
        raise Langsmith::APIError, "#{error_msg}\nRequest: #{request_info}"
      end
    end

    def get_thread(thread_id:)
      begin
        request(:get, "api/v1/threads/#{thread_id}")
      rescue StandardError => e
        request_info = "GET #{api_url}/api/v1/threads/#{thread_id}"
        raise Langsmith::APIError, "Failed to fetch thread: #{e.message}\nRequest: #{request_info}"
      end
    end

    def create_thread(name: nil, metadata: {})
      body = {
        name: name,
        metadata: metadata
      }.compact

      begin
        request(:post, "api/v1/threads", {}, body)
      rescue StandardError => e
        request_info = "POST #{api_url}/api/v1/threads\nBody: #{body.inspect}"
        raise Langsmith::APIError, "Failed to create thread: #{e.message}\nRequest: #{request_info}"
      end
    end

    def add_message(thread_id:, content:, additional_kwargs: {})
      body = {
        content: content,
        additional_kwargs: additional_kwargs
      }.compact

      begin
        request(:post, "api/v1/threads/#{thread_id}/messages", {}, body)
      rescue StandardError => e
        request_info = "POST #{api_url}/api/v1/threads/#{thread_id}/messages\nBody: #{body.inspect}"
        raise Langsmith::APIError, "Failed to add message: #{e.message}\nRequest: #{request_info}"
      end
    end

    def list_messages(thread_id:)
      begin
        request(:get, "api/v1/threads/#{thread_id}/messages")
      rescue StandardError => e
        request_info = "GET #{api_url}/api/v1/threads/#{thread_id}/messages"
        raise Langsmith::APIError, "Failed to list messages: #{e.message}\nRequest: #{request_info}"
      end
    end

    # Create feedback for a run
    # @param run_id [String] ID of the run
    # @param key [String] Feedback key
    # @param value [Object] Feedback value
    # @param comment [String, nil] Optional comment
    # @param feedback_id [String, nil] Optional feedback ID
    # @return [Hash] Response from the API
    def create_feedback(run_id:, key:, value:, comment: nil, feedback_id: nil)
      feedback_id ||= SecureRandom.uuid
      
      body = {
        id: feedback_id,
        run_id: run_id,
        key: key,
        value: value,
        comment: comment
      }.compact
      
      begin
        request(:post, "api/v1/feedback", {}, body)
      rescue StandardError => e
        request_info = "POST #{api_url}/api/v1/feedback\nBody: #{body.inspect}"
        raise Langsmith::APIError, "Failed to create feedback: #{e.message}\nRequest: #{request_info}"
      end
    end

    # List feedback for a run
    # @param run_id [String] ID of the run
    # @return [Array<Hash>] Array of feedback objects
    def list_run_feedback(run_id:)
      params = { run_id: run_id }
      
      begin
        request(:get, "api/v1/feedback", params)
      rescue StandardError => e
        request_info = "GET #{api_url}/api/v1/feedback\nParams: #{params.inspect}"
        raise Langsmith::APIError, "Failed to list run feedback: #{e.message}\nRequest: #{request_info}"
      end
    end

    # Update feedback for a run
    # @param feedback_id [String] ID of the feedback
    # @param value [Object] New feedback value
    # @param comment [String, nil] New comment
    # @return [Hash] Response from the API
    def update_feedback(feedback_id:, value: nil, comment: nil)
      body = {}.tap do |h|
        h[:value] = value unless value.nil?
        h[:comment] = comment unless comment.nil?
      end
      
      begin
        request(:patch, "api/v1/feedback/#{feedback_id}", {}, body)
      rescue StandardError => e
        request_info = "PATCH #{api_url}/api/v1/feedback/#{feedback_id}\nBody: #{body.inspect}"
        raise Langsmith::APIError, "Failed to update feedback: #{e.message}\nRequest: #{request_info}"
      end
    end

    # Delete feedback
    # @param feedback_id [String] ID of the feedback
    # @return [Hash] Response from the API
    def delete_feedback(feedback_id:)
      begin
        request(:delete, "api/v1/feedback/#{feedback_id}")
      rescue StandardError => e
        request_info = "DELETE #{api_url}/api/v1/feedback/#{feedback_id}"
        raise Langsmith::APIError, "Failed to delete feedback: #{e.message}\nRequest: #{request_info}"
      end
    end

    # Read a run
    # @param run_id [String] ID of the run
    # @return [Hash] Run object
    def read_run(run_id:)
      begin
        request(:get, "api/v1/runs/#{run_id}")
      rescue StandardError => e
        request_info = "GET #{api_url}/api/v1/runs/#{run_id}"
        raise Langsmith::APIError, "Failed to read run: #{e.message}\nRequest: #{request_info}"
      end
    end

    private

    def handle_response(response)
      if response.is_a?(Hash)
        response
      else
        status = response.status
        if status >= 200 && status < 300
          JSON.parse(response.body)
        else
          error_message = "API request failed with status #{status}"
          error_message += ": #{response.body}" if response.body
          raise Langsmith::APIError, error_message
        end
      end
    end
  end
end
