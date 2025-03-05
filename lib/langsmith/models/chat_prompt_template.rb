module Langsmith
  module Models
    class ChatPromptTemplate < BaseModel
      attr_reader :messages, :input_variables, :tools

      def self.pull(repo_name, commit_hash: nil, include_model: false)
        prompt_json = Langsmith.hub.pull(repo_name, commit_hash: commit_hash, include_model: include_model)
        from_json(prompt_json)
      end

      def initialize(messages:, input_variables:, tools: [])
        @messages = messages.map do |msg|
          case msg.dig("id", -1)
          when "SystemMessagePromptTemplate"
            Models::SystemMessageTemplate.from_json(msg)
          when "HumanMessagePromptTemplate"
            Models::HumanMessageTemplate.from_json(msg)
          end
        end.compact
        @input_variables = input_variables
        @tools = tools.is_a?(Array) ? tools : []
      end

      def self.from_json(json)
        return unless json["type"] == "constructor" &&
                     json["id"] == ["langchain", "prompts", "chat", "ChatPromptTemplate"]

        # Extract tools if present
        raw_tools = json.dig("kwargs", "tools") || []
        
        # Parse tools into proper Tool objects
        tools = raw_tools.map { |tool_json| Tool.from_json(tool_json) }.compact
        
        # Only keep the supported kwargs (ignore template_format or other unexpected kwargs)
        supported_kwargs = {
          messages: json.dig("kwargs", "messages"),
          input_variables: json.dig("kwargs", "input_variables"),
          tools: tools
        }.compact

        new(**supported_kwargs)
      end

      # Format the prompt with the given variables
      def format(**kwargs)
        missing = input_variables - kwargs.keys.map(&:to_s)
        raise ArgumentError, "Missing variables: #{missing.join(', ')}" if missing.any?

        messages = @messages.map do |message|
          message_vars = message.prompt.input_variables
          message_kwargs = kwargs.slice(*message_vars.map(&:to_sym))
          content = message.prompt.template.dup
          
          # Replace variables based on template format
          message_kwargs.each do |key, value|
            case message.prompt.template_format
            when "f-string"
              content.gsub!("{#{key}}", value.to_s)
            else
              # Default to % formatting
              content = content % { key => value }
            end
          end
          
          case message
          when Models::SystemMessageTemplate
            { role: "system", content: content }
          when Models::HumanMessageTemplate
            { role: "user", content: content }
          end
        end

        messages
      end
      
      # Get tool names
      def tool_names
        tools.map(&:name)
      end
      
      # Find a specific tool by name
      def get_tool(name)
        tools.find { |tool| tool.name == name }
      end
      
      # Check if this template has tools
      def has_tools?
        !tools.empty?
      end
    end
  end
end
