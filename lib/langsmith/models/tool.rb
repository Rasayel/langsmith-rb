module Langsmith
  module Models
    class Tool < BaseModel
      attr_reader :name, :description, :parameters, :type, :strict

      def initialize(name:, description:, parameters: {}, type: "function", strict: true, **kwargs)
        @name = name
        @description = description
        @parameters = parameters
        @type = type
        @strict = strict
        @additional_params = kwargs
      end

      def self.from_json(json)
        # Handle different formats of tool definitions
        if json["type"] == "function"
          # Direct function format
          function_data = json["function"]
          new(
            name: function_data["name"],
            description: function_data["description"],
            parameters: function_data["parameters"] || {},
            strict: function_data["strict"] || true
          )
        elsif json["kwargs"]&.key?("name")
          # Format where tool data is in kwargs
          new(
            name: json["kwargs"]["name"],
            description: json["kwargs"]["description"],
            parameters: json["kwargs"]["parameters"] || {},
            strict: json["kwargs"]["strict"] || true
          )
        else
          return nil
        end
      end

      # Convert to OpenAI function calling format
      def to_openai_tool
        {
          type: "function",
          function: {
            name: name,
            description: description,
            parameters: parameters,
            strict: strict
          }
        }
      end

      # Convert to Anthropic tool format
      def to_anthropic_tool
        {
          name: name,
          description: description,
          input_schema: parameters
        }
      end

      # Generic tool definition that works for most providers
      def to_tool_definition
        to_openai_tool
      end

      # Format for human-readable display
      def to_s
        params = parameters.dig("properties")&.map do |name, details|
          desc = details["description"] ? " - #{details["description"]}" : ""
          type = details["type"] ? " (#{details["type"]})" : ""
          "  - #{name}#{type}#{desc}"
        end&.join("\n") || "  None"

        required = parameters.dig("required") ? parameters["required"].join(", ") : "None"

        <<~TOOL
          #{name}:
            Description: #{description}
            Required Parameters: #{required}
            Parameters:
          #{params}
        TOOL
      end

      def to_h
        {
          type: type,
          function: {
            name: name,
            description: description,
            parameters: parameters,
            strict: strict
          }
        }
      end
    end
  end
end
