require "anthropic"

module Langsmith
  module Wrappers
    class Anthropic
      include Langsmith::Traceable

      attr_reader :client, :model

      def initialize(client = nil, **options)
        @client = client || ::Anthropic::Client.new(**options)
        @model_name = "claude-3-opus-20240229"
      end

      def call(messages:, model: "claude-3-opus-20240229", parent_run_id: nil, **kwargs)
        # Update model if provided
        @model_name = model
        
        # Convert messages to Anthropic format
        system_message = messages.find { |m| m[:role] == "system" }&.dig(:content)
        user_messages = messages.select { |m| m[:role] != "system" }

        response = @client.messages(
          model: model,
          system: system_message,
          messages: user_messages.map { |m|
            {
              role: m[:role],
              content: m[:content]
            }
          },
          **kwargs.except(:parent_run_id)
        )

        {
          model: response.model,
          choices: [
            {
              message: {
                role: response.role,
                content: response.content
              },
              finish_reason: response.stop_reason,
              index: 0
            }
          ],
          usage: response.usage.to_h
        }
      end
      
      # Make the call method traceable - AFTER the method definition
      traceable :call, run_type: "llm", name: "Anthropic Chat",
                metadata: { model_name: "claude-3-opus-20240229" }
    end

    def self.wrap_anthropic(client = nil, **options)
      Anthropic.new(client, **options)
    end
  end
end
