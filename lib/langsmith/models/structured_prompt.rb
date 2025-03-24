module Langsmith
  module Models
    class StructuredPrompt < ChatPromptTemplate
      attr_accessor :schema, :structured_output_kwargs

      def initialize(messages:, schema: nil, structured_output_kwargs: {})
        @messages = messages
        @schema = schema
        @structured_output_kwargs = structured_output_kwargs
        super(messages: messages)
      end

      def self.from_messages_and_schema(messages, schema, **kwargs)
        new(messages: messages, schema: schema, **kwargs)
      end

      def self.from_json(json)
        return unless json["type"] == "constructor" &&
                     json["id"] == ["langchain", "prompts", "structured", "StructuredPrompt"]

        # Extract schema and structured_output_kwargs if present
        schema = json.dig("kwargs", "schema")
        structured_output_kwargs = json.dig("kwargs", "structured_output_kwargs") || {}

        # Only keep the supported kwargs
        supported_kwargs = {
          messages: json.dig("kwargs", "messages"),
          schema: schema,
          structured_output_kwargs: structured_output_kwargs
        }.compact

        new(**supported_kwargs)
      end
    end
  end
end
