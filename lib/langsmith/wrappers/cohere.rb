require "cohere"

module Langsmith
  module Wrappers
    class Cohere
      include Langsmith::Traceable

      attr_reader :client, :model

      def initialize(client = nil, **options)
        @client = client || ::Cohere::Client.new(**options)
        @model_name = "command"
      end

      def call(messages:, model: "command", parent_run_id: nil, **kwargs)
        # Update model if provided
        @model_name = model
        
        chat_history = messages[0...-1].map do |m|
          {
            role: m[:role] == "assistant" ? "CHATBOT" : "USER",
            message: m[:content]
          }
        end

        response = @client.chat(
          message: messages.last[:content],
          model: model,
          chat_history: chat_history,
          **kwargs.except(:parent_run_id)
        )

        {
          model: model,
          choices: [
            {
              message: {
                role: "assistant",
                content: response.text
              },
              finish_reason: response.finish_reason,
              index: 0
            }
          ],
          usage: {
            prompt_tokens: response.token_count&.prompt_tokens,
            completion_tokens: response.token_count&.response_tokens,
            total_tokens: response.token_count&.total_tokens
          }
        }
      end
      
      # Make the call method traceable - AFTER the method definition
      traceable :call, run_type: "llm", name: "Cohere Chat",
                metadata: { model_name: "command" }
    end

    def self.wrap_cohere(client = nil, **options)
      Cohere.new(client, **options)
    end
  end
end
