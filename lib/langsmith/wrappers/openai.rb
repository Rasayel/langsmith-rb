require "openai"

module Langsmith
  module Wrappers
    class OpenAI
      include Langsmith::Traceable

      # Set up tracing for OpenAI calls
     
      def initialize(client = nil, **options)
        @client = client || ::OpenAI::Client.new(**options)
        @model = options[:model] || "gpt-3.5-turbo"
      end

      def call(messages:, model: nil, temperature: 0.7, parent_run_id: nil, **options)
        @model = model || @model  # Update model if provided

        # Filter out non-OpenAI parameters
        openai_params = {
          model: @model,
          messages: messages,
          temperature: temperature
        }
        
        # Only include valid OpenAI parameters
        valid_params = %w[
          model messages temperature max_tokens top_p frequency_penalty
          presence_penalty stop n stream logit_bias user response_format
          seed tools tool_choice
        ]
        
        options.each do |key, value|
          openai_params[key] = value if valid_params.include?(key.to_s)
        end

        begin
          response = @client.chat(
            parameters: openai_params
          )
        rescue StandardError => e
          raise Langsmith::APIError, "Failed to get completion: #{e.message}"
        end

        {
          "model" => response.dig("model"),
          "choices" => response.dig("choices")&.map { |c| 
            {
              "message" => c["message"],
              "finish_reason" => c["finish_reason"],
              "index" => c["index"]
            }
          },
          "usage" => response.dig("usage")
        }
      end

      traceable(
        run_type: "llm",
        name: "Open AI",
        parent_run_id: lambda { |obj, *args, **kwargs| kwargs[:parent_run_id] },
        metadata: { model_name: @model_name}
      )

    end

    def wrap_openai(client = nil, **options)
      ::Langsmith::Wrappers::OpenAI.new(client, **options)
    end
  end
end
