module Langsmith
  class Chat
    include Traceable

    attr_reader :llm, :thread_id, :project_name, :context, :parent_run_id, :tools

    def initialize(llm: nil, thread_id: SecureRandom.uuid, project_name: nil, context: {}, parent_run_id: nil, tool_implementations: {}, prompt: nil, custom_tools: [])
      @llm = llm || Langsmith.wrap_openai
      @thread_id = thread_id
      @project_name = project_name || Langsmith.configuration.project_name
      @context = context
      @parent_run_id = parent_run_id
      @tools = {}
      @prompt = prompt
      
      # Initialize tools from prompt if available
      if @prompt&.tools&.any?
        @prompt.tools.each do |tool_def|
          implementation = tool_implementations[tool_def.name]
          unless implementation
            raise Langsmith::ConfigurationError, 
              "No implementation provided for tool '#{tool_def.name}'. Available tools: #{tool_implementations.keys.join(', ')}"
          end

          @tools[tool_def.name] = Langsmith::Wrappers::Tool.new(
            name: tool_def.name,
            description: tool_def.description,
            parameters: tool_def.parameters,
            &implementation
          )
        end
      end

      # Add custom tools with their own definitions
      custom_tools.each do |tool_def|
        implementation = tool_implementations[tool_def[:name]]
        unless implementation
          raise Langsmith::ConfigurationError, 
            "No implementation provided for custom tool '#{tool_def[:name]}'. Available tools: #{tool_implementations.keys.join(', ')}"
        end

        @tools[tool_def[:name]] = Langsmith::Wrappers::Tool.new(
          name: tool_def[:name],
          description: tool_def[:description],
          parameters: tool_def[:parameters],
          &implementation
        )
      end

      # Check for any unused implementations
      unused = tool_implementations.keys - @tools.keys
      if unused.any?
        raise Langsmith::ConfigurationError,
          "Tool implementations provided but not defined in prompt or custom_tools: #{unused.join(', ')}"
      end
    end

    def call(prompt_or_messages, **inputs)
      run_tree = RunTree.new(
        name: inputs.delete(:name) || "langsmith.chat",
        run_type: "chain",
        inputs: inputs,
        metadata: {
          "thread_id" => thread_id,
          "session_id" => thread_id,
          "available_tools" => tools.keys
        },
        parent_run_id: parent_run_id
      )
      run_tree.post

      begin
        # Format messages if needed
        messages = if prompt_or_messages.is_a?(Models::ChatPromptTemplate)
          @prompt = prompt_or_messages # Store for future use
          prompt_or_messages.format(**inputs)
        else
          prompt_or_messages
        end

        # Call the LLM with tool definitions
        response = llm.call(
          messages: messages,
          tools: @tools.values.map(&:to_tool_definition),
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
            tools: @tools.values.map(&:to_tool_definition),
            parent_run_id: run_tree.id
          )
        end

        # Extract the final response
        content = response.dig("choices", 0, "message", "content")
        
        # Update run with success
        run_tree.end(
          outputs: {
            response: content,
            messages: messages
          }
        )
        run_tree.patch

        content
      rescue StandardError => e
        run_tree.end(error: e.message)
        run_tree.patch
        raise
      end
    end
  end
end
