module Langsmith
  module Models
    class StructuredPrompt < ChatPromptTemplate
      attr_accessor :schema, :structured_output_kwargs

      def initialize(messages:, schema: nil, structured_output_kwargs: {}, input_variables:, tools: [])
        @messages = messages
        @schema = schema
        @structured_output_kwargs = structured_output_kwargs
        super(messages: messages, input_variables: input_variables, tools: tools)
      end

      def self.from_json(json)
        return unless json["type"] == "constructor" &&
                     json["id"] == ["langchain_core", "prompts", "structured", "StructuredPrompt"]

        # Extract schema and structured_output_kwargs if present
        schema = json.dig("kwargs", "schema")
        structured_output_kwargs = json.dig("kwargs", "structured_output_kwargs") || {}

        raw_tools = json.dig("kwargs", "tools") || []
        
        # Parse tools into proper Tool objects
        tools = raw_tools.map { |tool_json| Tool.from_json(tool_json) }.compact

        # Only keep the supported kwargs
        supported_kwargs = {
          messages: json.dig("kwargs", "messages"),
          schema: schema,
          structured_output_kwargs: structured_output_kwargs,
          input_variables: json.dig("kwargs", "input_variables"),
          tools: tools
        }.compact

        new(**supported_kwargs)
      end
    end
  end
end
