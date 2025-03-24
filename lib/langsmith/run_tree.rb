require "time"
require "securerandom"

module Langsmith
  class RunTree
    attr_reader :name, :run_type, :inputs, :outputs, :error, :start_time, :end_time, 
                :runtime, :reference_example_id, :parent_run_id, :tags, :metadata,
                :session_id, :session_name, :id, :client, :project_name

    # Create a new run tree
    # @param name [String] Name of the run
    # @param run_type [String] Type of run (e.g., "chain", "llm", "tool")
    # @param inputs [Hash] Input values for the run
    # @param outputs [Hash, nil] Output values (if already available)
    # @param error [String, nil] Error message (if any)
    # @param reference_example_id [String, nil] Associated example ID (if any)
    # @param parent_run_id [String, nil] Parent run ID (if any)
    # @param tags [Array<String>] Tags to associate with the run
    # @param metadata [Hash] Metadata for the run
    # @param session_id [String, nil] Session ID for grouping related runs
    # @param session_name [String, nil] Session Name for grouping related runs
    # @param project_name [String, nil] Project name to use
    # @param client [Langsmith::Client] Client to use for API calls
    def initialize(
      name:,
      run_type:,
      inputs: {},
      outputs: nil,
      error: nil, 
      reference_example_id: nil,
      run_id: nil,
      parent_run_id: nil,
      tags: [],
      metadata: {},
      session_id: nil,
      session_name: nil,
      project_name: nil,
      client: Langsmith.client
    )
      @name = name
      @run_type = run_type
      @inputs = inputs
      @outputs = outputs
      @error = error
      @reference_example_id = reference_example_id
      @parent_run_id = parent_run_id
      @tags = tags
      @metadata = metadata
      @session_id = session_id
      @session_name = session_name
      @project_name = project_name || Langsmith.configuration.project_name
      @client = client
      @start_time = Time.now.utc
      @id = run_id || SecureRandom.uuid # Generate ID at initialization
    end

    # Post the run to LangSmith
    # @return [Hash] Response from the API
    def post
      response = client.create_run(
        name: name,
        run_type: run_type,
        start_time: start_time,
        inputs: inputs,
        parent_run_id: parent_run_id,
        tags: tags,
        metadata: metadata,
        session_id: session_id,
        session_name: session_name,
        status: "started",
        run_id: id, # Use our pre-generated ID
        project_name: project_name
      )
      response
    end

    # End the run with outputs or error
    # @param outputs [Hash, nil] Output values
    # @param error [String, nil] Error message
    # @return [self] The run tree instance
    def end(outputs: nil, error: nil)
      @end_time = Time.now.utc
      @runtime = @end_time - @start_time
      @outputs = outputs
      @error = error
      self
    end

    # Update the run in LangSmith
    # @return [Hash] Response from the API
    def patch
      raise "No run ID available" unless @id

      client.update_run(
        run_id: @id,
        end_time: end_time,
        error: error,
        outputs: outputs,
        status: error ? "error" : "completed"
      )
    end

    # Update the run in LangSmith (alias for patch)
    # @param outputs [Hash, nil] Output values
    # @param error [String, nil] Error message
    # @return [Hash] Response from the API
    def update(outputs = nil, error = nil)
      if outputs || error
        @outputs = outputs if outputs
        @error = error if error
      end
      
      patch
    end

    # Create a child run tree
    # @param name [String] Name of the child run
    # @param run_type [String] Type of child run
    # @param inputs [Hash] Input values for the child run
    # @param tags [Array<String>] Tags for the child run
    # @param metadata [Hash] Metadata for the child run
    # @param auto_post [Boolean] Whether to automatically post the run
    # @return [RunTree] The child run tree
    def create_child(name:, run_type:, inputs: {}, tags: [], metadata: {}, auto_post: false)
      child = RunTree.new(
        name: name,
        run_type: run_type,
        inputs: inputs,
        parent_run_id: id,
        tags: tags,
        metadata: metadata,
        session_id: session_id,
        project_name: project_name,
        client: client
      )
      
      child.post if auto_post
      child
    end

    # Create a child run tree and execute a block with tracing
    # @param name [String] Name of the child run
    # @param run_type [String] Type of child run
    # @param inputs [Hash] Input values for the child run
    # @param tags [Array<String>] Tags for the child run
    # @param metadata [Hash] Metadata for the child run
    # @yield [RunTree] The child run tree
    # @return [Object] The result of the block
    def trace(name:, run_type:, inputs: {}, tags: [], metadata: {})
      # Create the child run
      child = create_child(
        name: name,
        run_type: run_type,
        inputs: inputs,
        tags: tags,
        metadata: metadata,
        auto_post: true
      )
      
      # Save the previous run to restore it later
      previous_run = Langsmith.current_run_tree
      
      begin
        # Set the child as the current run
        Langsmith.set_current_run_tree(child)
        
        # Yield to the block with the child run
        result = yield(child)
        
        # End the child run
        child.end(outputs: result.is_a?(Hash) ? result : { output: result })
        child.patch
        
        # Return the result
        result
      rescue StandardError => e
        # End with error
        child.end(error: e.message)
        child.patch
        raise
      ensure
        # Restore the previous run
        Langsmith.set_current_run_tree(previous_run)
      end
    end

    # Get feedback for this run
    # @return [Array<Hash>] Array of feedback objects
    def get_feedback
      client.list_run_feedback(run_id: id)
    end

    # Add feedback to this run
    # @param key [String] Feedback key
    # @param value [Object] Feedback value
    # @param comment [String, nil] Optional comment
    # @return [Hash] Response from the API
    def add_feedback(key:, value:, comment: nil)
      client.create_feedback(
        run_id: id,
        key: key,
        value: value,
        comment: comment
      )
    end
  end
end
