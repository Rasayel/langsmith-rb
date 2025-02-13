module Langsmith
  module Models
    class ChatPromptTemplate < BaseModel
      attr_reader :messages, :input_variables, :tools

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
        @tools = tools.map { |tool| Tool.from_json(tool) }.compact
      end

      def self.from_json(json)
        return unless json["type"] == "constructor" &&
                     json["id"] == ["langchain", "prompts", "chat", "ChatPromptTemplate"]

        # Extract tools if present
        tools = json.dig("kwargs", "tools") || []
        kwargs = json["kwargs"].transform_keys(&:to_sym)
        kwargs[:tools] = tools

        new(**kwargs)
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
    end

    # Tool class to represent LangSmith tools
    class Tool < BaseModel
      attr_reader :name, :description, :parameters

      def initialize(name:, description:, parameters: {})
        @name = name
        @description = description
        @parameters = parameters
      end

      def self.from_json(json)
        return unless json["type"] == "constructor" &&
                     json["id"]&.include?("tools")

        new(
          name: json["kwargs"]["name"],
          description: json["kwargs"]["description"],
          parameters: json["kwargs"]["parameters"] || {}
        )
      end

      def to_s
        params = parameters.map { |k, v| "  - #{k}: #{v}" }.join("\n")
        <<~TOOL
          #{name}:
            Description: #{description}
            Parameters:
          #{params}
        TOOL
      end

      def to_tool_definition
        {
          type: "function",
          function: {
            name: name,
            description: description,
            parameters: parameters
          }
        }
      end
    end
  end
end
