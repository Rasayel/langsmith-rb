module Langsmith
  module Wrappers
    class Tool
      include Langsmith::Traceable

      attr_reader :name, :description, :parameters

      def initialize(name:, description:, parameters: nil, &implementation)
        @name = name
        @description = description
        @parameters = parameters
        @implementation = implementation
      end

      def self.define(name:, description:, parameters: nil, &implementation)
        new(
          name: name,
          description: description,
          parameters: parameters,
          &implementation
        )
      end

      def to_tool_definition
        {
          "type" => "function",
          "function" => {
            "name" => name,
            "description" => description,
            "parameters" => parameters || {
              "type" => "object",
              "properties" => {},
              "required" => []
            }
          }
        }
      end

      def call(input:, parent_run_id: nil)
        run_tree = Langsmith::RunTree.new(
          name: name,
          run_type: "tool",
          inputs: input,
          parent_run_id: parent_run_id
        )
        run_tree.post

        begin
          result = @implementation.call(input)
          
          run_tree.end(
            outputs: { result: result }
          )
          run_tree.patch

          { result: result }
        rescue StandardError => e
          run_tree.end(error: e.message)
          run_tree.patch
          raise Langsmith::APIError, "Tool execution failed: #{e.message}"
        end
      end

      # Set up tracing for tool calls
      traceable(
        :call, 
        run_type: "tool",
        name: -> { "langsmith.tool.#{@name}" },
        metadata: -> { { 
          "tool_name" => @name,
          "tool_description" => @description 
        } },
        parent_run_id: lambda { |obj, *args, **kwargs| kwargs[:parent_run_id] }
      )
    end

    def wrap_tool(name:, description:, &block)
      Tool.new(name: name, description: description, &block)
    end
  end
end
