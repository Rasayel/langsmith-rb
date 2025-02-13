module Langsmith
  module Models
    class PromptTemplate < BaseModel
      attr_reader :input_variables, :template_format, :template

      def initialize(input_variables:, template_format:, template:)
        @input_variables = input_variables
        @template_format = template_format
        @template = template
      end

      def self.from_json(json)
        return unless json["type"] == "constructor" && 
                     json["id"] == ["langchain", "prompts", "prompt", "PromptTemplate"]

        new(**json["kwargs"].transform_keys(&:to_sym))
      end

      def append_text(text)
        @template = @template.dup + text
      end
    end
  end
end
