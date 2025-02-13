module Langsmith
  module Models
    class MessageTemplate < BaseModel
      attr_reader :prompt

      def initialize(prompt:)
        @prompt = PromptTemplate.from_json(prompt)
      end

      def self.from_json(json)
        return unless json["type"] == "constructor" &&
                     json["id"].first(3) == ["langchain", "prompts", "chat"]

        new(**json["kwargs"].transform_keys(&:to_sym))
      end

      def role
        raise NotImplementedError, "Subclasses must implement role"
      end

      def content
        @prompt.template
      end
    end

    class SystemMessageTemplate < MessageTemplate
      def self.from_json(json)
        return unless super && json["id"].last == "SystemMessagePromptTemplate"
        new(**json["kwargs"].transform_keys(&:to_sym))
      end

      def role
        "system"
      end
    end

    class HumanMessageTemplate < MessageTemplate
      def self.from_json(json)
        return unless super && json["id"].last == "HumanMessagePromptTemplate"
        new(**json["kwargs"].transform_keys(&:to_sym))
      end

      def role
        "user"
      end
    end

    class AIMessageTemplate < MessageTemplate
      def self.from_json(json)
        return unless super && json["id"].last == "AIMessagePromptTemplate"
        new(**json["kwargs"].transform_keys(&:to_sym))
      end

      def role
        "assistant"
      end
    end
  end
end
