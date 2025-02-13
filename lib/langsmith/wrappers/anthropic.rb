require "anthropic"

module Langsmith
  module Wrappers
    class Anthropic
      include Langsmith::Traceable

      def initialize(client = nil, **options)
        @client = client || ::Anthropic::Client.new(**options)
      end

      def call(messages:, model: "claude-3-opus-20240229", parent_run_id: nil, **kwargs)
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

      traceable(
        run_type: "llm",
        name: "Anthropic Chat",
        parent_run_id: lambda { |obj, *args, **kwargs| kwargs[:parent_run_id] }
      )
    end

    def self.wrap_anthropic(client = nil, **options)
      Anthropic.new(client, **options)
    end
  end
end
