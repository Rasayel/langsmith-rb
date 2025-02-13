require "time"
require "securerandom"

module Langsmith
  class RunTree
    attr_reader :name, :run_type, :inputs, :outputs, :error, :start_time, :end_time, 
                :runtime, :reference_example_id, :parent_run_id, :tags, :metadata,
                :session_id, :id, :client

    def initialize(
      name:,
      run_type:,
      inputs: {},
      outputs: nil,
      error: nil, 
      reference_example_id: nil,
      parent_run_id: nil,
      tags: [],
      metadata: {},
      session_id: nil,
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
      @client = client
      @start_time = Time.now.utc
      @id = SecureRandom.uuid # Generate ID at initialization
    end

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
        status: "started",
        run_id: id # Use our pre-generated ID
      )
      response
    end

    def end(outputs: nil, error: nil)
      @end_time = Time.now.utc
      @runtime = @end_time - @start_time
      @outputs = outputs
      @error = error
    end

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

    def create_child(name:, run_type:, inputs: {}, tags: [], metadata: {})
      RunTree.new(
        name: name,
        run_type: run_type,
        inputs: inputs,
        parent_run_id: id,
        tags: tags,
        metadata: metadata,
        session_id: session_id,
        client: client
      )
    end
  end
end
