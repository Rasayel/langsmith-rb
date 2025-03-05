module Langsmith
  # Class for managing run operations in LangSmith
  # Provides advanced filtering, querying, and batch operations
  class RunManager
    attr_reader :client
    
    # Initialize a RunManager
    # @param client [Langsmith::Client] Client to use for API calls
    def initialize(client = Langsmith.client)
      @client = client
    end
    
    # Fetch runs using the client API
    # @param filters [Hash] Filters to apply to the runs request. Available filters:
    #   - parent_run_id [String] Parent run ID to filter by (recommended approach)
    #   - trace_id [String] Trace ID to filter by 
    #   - run_type [String] Run type to filter by (e.g., "llm", "chain", "tool")
    #   - session_id [String, Array<String>] Session ID(s) to filter by
    #                Must be valid UUIDs that already exist in LangSmith
    #   - filter_tags [Array<String>] Tags to filter by
    #   - trace_tags [Array<String>] Alias for filter_tags
    #   - run_name [String] Run name to filter by
    #   - start_time [Time] Start time for filtering runs
    #   - end_time [Time] End time for filtering runs
    # @note The LangSmith API requires at least one identifier: parent_run_id, trace_id, or session_id
    #       with valid values. The most reliable approach is:
    #       1. Query for top-level runs using filter_tags and project_name
    #       2. Then query for child runs using parent_run_id once you have a valid run ID
    # @param project_name [String, nil] Project name to filter by (defaults to configured project)
    # @param limit [Integer] Maximum number of runs to fetch
    # @param offset [Integer] Offset for pagination
    # @return [Array<Hash>] Array of run objects
    # @example Reliable approach to fetch runs
    #   # First get top-level runs by project and tags
    #   runs = run_manager.get_runs(
    #     filters: { 
    #       run_type: "chain",
    #       filter_tags: ["my_tag"]
    #     },
    #     limit: 5
    #   )
    #   
    #   # Then get child runs using a parent_run_id
    #   if runs.any?
    #     child_runs = run_manager.get_runs(
    #       filters: { parent_run_id: runs.first['id'] },
    #       limit: 5
    #     )
    #   end
    def get_runs(filters: {}, project_name: nil, limit: 50, offset: 0)
      modified_filters = filters.dup
      
      # Move trace_tags to filter_tags for API compatibility
      if modified_filters[:trace_tags]
        modified_filters[:filter_tags] = modified_filters.delete(:trace_tags)
      end
      
      # Extract keys that go directly to list_runs
      project = project_name || Langsmith.configuration.project_name
      parent_run_id = modified_filters.delete(:parent_run_id)
      trace_id = modified_filters.delete(:trace_id)
      run_type = modified_filters.delete(:run_type)
      session_id = modified_filters.delete(:session_id)
      filter_tags = modified_filters.delete(:filter_tags)
      run_name = modified_filters.delete(:run_name)
      start_time = modified_filters.delete(:start_time)
      end_time = modified_filters.delete(:end_time)
      
      # Call the client with the extracted parameters
      client.list_runs(
        project_name: project,
        parent_run_id: parent_run_id,
        trace_id: trace_id,
        run_type: run_type,
        session_id: session_id,
        filter_tags: filter_tags,
        run_name: run_name,
        start_time: start_time,
        end_time: end_time,
        limit: limit,
        offset: offset
      )
    end
    
    # Get a run and all its children recursively
    # @param run_id [String] ID of the run to get
    # @param include_children [Boolean] Whether to include child runs
    # @return [Hash] Run object with children
    def get_run_tree(run_id, include_children: true)
      run = client.read_run(run_id: run_id)
      
      if include_children
        children = get_runs(
          filters: { parent_run_id: run_id },
          limit: 100
        )
        
        run[:children] = children.map do |child|
          get_run_tree(child[:id])
        end
      end
      
      run
    end
    
    # Add feedback to a run
    # @param run_id [String] ID of the run
    # @param key [String] Feedback key
    # @param value [Object] Feedback value
    # @param comment [String, nil] Optional comment
    # @return [Hash] Response from the API
    def add_feedback(run_id:, key:, value:, comment: nil)
      client.create_feedback(
        run_id: run_id,
        key: key,
        value: value,
        comment: comment
      )
    end
    
    # Get feedback for a run
    # @param run_id [String] ID of the run
    # @return [Array<Hash>] Array of feedback objects
    def get_feedback(run_id:)
      client.list_run_feedback(run_id: run_id)
    end
    
    # Get runs by session ID
    # @param session_id [String] Session ID to filter by
    # @param limit [Integer] Maximum number of runs to return
    # @return [Array<Hash>] Array of run objects
    def get_session_runs(session_id:, limit: 100)
      get_runs(
        filters: { session_id: session_id },
        limit: limit
      )
    end
    
    # Get runs by trace ID (top-level run)
    # @param trace_id [String] Trace ID to filter by
    # @param limit [Integer] Maximum number of runs to return
    # @return [Array<Hash>] Array of run objects
    def get_trace_runs(trace_id:, limit: 100)
      # Get the trace (top-level run)
      run = client.read_run(run_id: trace_id)
      
      # Get all runs in this trace
      get_runs(
        filters: { trace_id: run[:trace_id] },
        limit: limit
      )
    end
    
    # Get runs by tag
    # @param tag [String] Tag to filter by
    # @param project_name [String, nil] Project to filter by
    # @param limit [Integer] Maximum number of runs to return
    # @return [Array<Hash>] Array of run objects
    def get_runs_by_tag(tag:, project_name: nil, limit: 50)
      get_runs(
        filters: { filter_tags: [tag] },
        project_name: project_name,
        limit: limit
      )
    end
    
    # Get runs by tags
    # @param tags [Array<String>] Tags to filter by
    # @param project_name [String, nil] Project to filter by
    # @param limit [Integer] Maximum number of runs to return
    # @return [Array<Hash>] Array of run objects
    def get_runs_by_tags(tags:, project_name: nil, limit: 50)
      get_runs(
        filters: { filter_tags: tags },
        project_name: project_name,
        limit: limit
      )
    end
    
    # Get runs by name
    # @param name [String] Name to filter by
    # @param project_name [String, nil] Project to filter by
    # @param limit [Integer] Maximum number of runs to return
    # @return [Array<Hash>] Array of run objects
    def get_runs_by_name(name:, project_name: nil, limit: 50)
      get_runs(
        filters: { run_name: name },
        project_name: project_name,
        limit: limit
      )
    end
    
    # Get runs by type
    # @param run_type [String] Run type to filter by
    # @param project_name [String, nil] Project to filter by
    # @param limit [Integer] Maximum number of runs to return
    # @return [Array<Hash>] Array of run objects
    def get_runs_by_type(run_type:, project_name: nil, limit: 50)
      get_runs(
        filters: { run_type: run_type },
        project_name: project_name,
        limit: limit
      )
    end
    
    # Get runs within a time range
    # @param start_time [Time] Start time
    # @param end_time [Time] End time
    # @param project_name [String, nil] Project to filter by
    # @param limit [Integer] Maximum number of runs to return
    # @return [Array<Hash>] Array of run objects
    def get_runs_by_time_range(start_time:, end_time:, project_name: nil, limit: 50)
      get_runs(
        filters: {
          start_time: start_time.utc.iso8601,
          end_time: end_time.utc.iso8601
        },
        project_name: project_name,
        limit: limit
      )
    end
  end
end
