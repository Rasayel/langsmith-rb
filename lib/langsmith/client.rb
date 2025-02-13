require "securerandom"
require "faraday"
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

    def connection
      @connection ||= Faraday.new(url: api_url) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        f.headers["x-api-key"] = api_key
        f.headers["Content-Type"] = "application/json"
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

      response = connection.post("api/v1/runs") do |req|
        req.body = body
      end

      handle_response(response)
    rescue StandardError => e
      request_info = "POST #{api_url}/api/v1/runs\nBody: #{response&.env&.request_body.inspect}"
      raise Langsmith::APIError, "Failed to create run: #{e.message}\nRequest: #{request_info}"
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

      response = connection.patch("api/v1/runs/#{run_id}") do |req|
        req.body = body
      end

      handle_response(response)
    rescue StandardError => e
      request_info = "PATCH #{api_url}/api/v1/runs/#{run_id}\nBody: #{response&.env&.request_body.inspect}"
      raise Langsmith::APIError, "Failed to update run: #{e.message}\nRequest: #{request_info}"
    end

    def get_run(run_id:)
      response = connection.get("api/v1/runs/#{run_id}")
      handle_response(response)
    rescue StandardError => e
      request_info = "GET #{api_url}/api/v1/runs/#{run_id}"
      raise Langsmith::APIError, "Failed to get run: #{e.message}\nRequest: #{request_info}"
    end

    # Pull a prompt from LangChain Hub
    def pull_prompt(repo_name)
      # First get the repo details using the current workspace (-)
      repo_response = connection.get("api/v1/repos/-/#{repo_name}")
      repo_data = handle_response(repo_response)["repo"]

      # Get the commit details using the last commit hash
      commit_hash = repo_data["last_commit_hash"]
      commit_response = connection.get("api/v1/commits/-/#{repo_name}/#{commit_hash}")
      commit_data = handle_response(commit_response)

      # Return the manifest from the commit data
      commit_data["manifest"]
    end

    def list_runs(
      project_name: nil,
      run_type: nil,
      start_time: nil,
      end_time: nil,
      limit: 100
    )
      params = {
        project_name: project_name,
        run_type: run_type,
        start_time: start_time&.iso8601,
        end_time: end_time&.iso8601,
        limit: limit
      }.compact

      response = connection.get("api/v1/runs", params)
      handle_response(response)
    rescue StandardError => e
      request_info = "GET #{api_url}/api/v1/runs\nParams: #{params.inspect}"
      raise Langsmith::APIError, "Failed to list runs: #{e.message}\nRequest: #{request_info}"
    end

    def list_runs(parent_run_id: nil, run_type: nil, filter: nil, project_name: nil, session: nil)
      response = connection.post("/api/v1/runs/query") do |req|
        req.body = {
          parent_run: parent_run_id,
          run_type: run_type,
          filter: filter,
          project_name: project_name || Langsmith.configuration.project_name,
          session: session.is_a?(Array) ? session : [session].compact
        }.compact
      end
      handle_response(response)
    rescue StandardError => e
      request_info = "POST #{api_url}/api/v1/runs/query\nBody: #{response&.env&.request_body.inspect}"
      raise Langsmith::APIError, "Failed to list runs: #{e.message}\nRequest: #{request_info}"
    end

    def get_thread(thread_id:)
      response = connection.get("/api/v1/threads/#{thread_id}")
      handle_response(response)
    rescue StandardError => e
      request_info = "GET #{api_url}/api/v1/threads/#{thread_id}"
      raise Langsmith::APIError, "Failed to fetch thread: #{e.message}\nRequest: #{request_info}"
    end

    def create_thread(name: nil, metadata: {})
      response = connection.post("/api/v1/threads") do |req|
        req.body = {
          name: name,
          metadata: metadata
        }.compact
      end
      handle_response(response)
    rescue StandardError => e
      request_info = "POST #{api_url}/api/v1/threads\nBody: #{response&.env&.request_body.inspect}"
      raise Langsmith::APIError, "Failed to create thread: #{e.message}\nRequest: #{request_info}"
    end

    def add_message(thread_id:, content:, additional_kwargs: {})
      response = connection.post("/api/v1/threads/#{thread_id}/messages") do |req|
        req.body = {
          content: content,
          additional_kwargs: additional_kwargs
        }.compact
      end
      handle_response(response)
    rescue StandardError => e
      request_info = "POST #{api_url}/api/v1/threads/#{thread_id}/messages\nBody: #{response&.env&.request_body.inspect}"
      raise Langsmith::APIError, "Failed to add message: #{e.message}\nRequest: #{request_info}"
    end

    def list_messages(thread_id:)
      response = connection.get("/api/v1/threads/#{thread_id}/messages")
      handle_response(response)
    rescue StandardError => e
      request_info = "GET #{api_url}/api/v1/threads/#{thread_id}/messages"
      raise Langsmith::APIError, "Failed to list messages: #{e.message}\nRequest: #{request_info}"
    end

    private

    def parse_owner_repo_commit(owner_repo_commit)
      parts = owner_repo_commit.split(/[\/:]/)
      case parts.length
      when 1
        ["langchain", parts[0], nil]  # Just repo name
      when 2
        [*parts, nil]  # owner/repo
      when 3
        parts  # owner/repo:commit
      else
        raise Langsmith::ArgumentError, "Invalid format. Expected: 'name', 'owner/name', or 'owner/name:commit'"
      end
    end

    def handle_response(response)
      unless response.success?
        error_message = "API request failed: #{response.status} - #{response.body.inspect}"
        request_info = "#{response.env.method.upcase} #{response.env.url}"
        raise Langsmith::APIError, "#{error_message}\nRequest: #{request_info}"
      end

      response.body
    end
  end
end
