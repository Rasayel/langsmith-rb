module Langsmith
  class Chain
    include Traceable

    attr_reader :prompt_name, :llm, :run_tree, :tools

    def initialize(prompt_name:, llm: nil, tool_implementations: {})
      @prompt_name = prompt_name
      @llm = llm || Langsmith.wrap_openai
      @tool_implementations = tool_implementations
      @tools = {}
    end

    def call(**inputs)
      # Create a run tree for this chain execution
      @run_tree = RunTree.new(
        name: prompt_name,
        run_type: "chain",
        inputs: inputs,
        metadata: {
          "available_tools" => @tools.keys
        }
      )
      @run_tree.post

      begin
        # Load and format the prompt
        prompt_json = Langsmith.hub.pull(prompt_name)
        prompt = Models::ChatPromptTemplate.from_json(prompt_json)

        # Create tool instances if not already created
        if @tools.empty? && prompt.tools.any?
          prompt.tools.each do |tool_def|
            implementation = @tool_implementations[tool_def.name]
            unless implementation
              raise Langsmith::ConfigurationError, 
                "No implementation provided for tool '#{tool_def.name}'. Available tools: #{@tool_implementations.keys.join(', ')}"
            end

            @tools[tool_def.name] = Langsmith::Wrappers::Tool.new(
              name: tool_def.name,
              description: tool_def.description,
              &implementation
            )
          end
        end

        # Format messages
        messages = prompt.format(**inputs)

        # Call the LLM with the chain's run ID as parent
        response = llm.call(
          messages: messages,
          parent_run_id: run_tree.id
        )

        # Handle tool calls if present
        if response.dig("choices", 0, "message", "tool_calls")
          tool_calls = response.dig("choices", 0, "message", "tool_calls")
          tool_calls.each do |tool_call|
            tool_name = tool_call.dig("function", "name")
            tool_args = JSON.parse(tool_call.dig("function", "arguments"))
            
            if tool = @tools[tool_name]
              # Execute and trace the tool
              tool_result = tool.call(
                input: tool_args,
                parent_run_id: run_tree.id
              )
              
              # Add tool response back to messages
              messages << {
                role: "assistant",
                content: nil,
                tool_calls: [tool_call]
              }
              messages << {
                role: "tool",
                content: tool_result[:result].to_s,
                tool_call_id: tool_call["id"]
              }
            end
          end
          
          # Get final response after tool usage
          response = llm.call(
            messages: messages,
            parent_run_id: run_tree.id
          )
        end

        # Extract the response
        content = response.dig("choices", 0, "message", "content")

        # Update the run with success
        run_tree.end(
          outputs: {
            response: content,
            messages: messages,
            model: response["model"],
            usage: response["usage"]
          }
        )
        run_tree.patch

        content
      rescue StandardError => e
        # Update the run with error
        run_tree.end(error: e.message)
        run_tree.patch
        raise Langsmith::APIError, "Failed to execute chain: #{e.message}"
      end
    end
  end
end
