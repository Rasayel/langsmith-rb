module Langsmith
  module Models
    class Model < BaseModel
      attr_reader :provider, :model, :temperature, :top_p, :presence_penalty, :frequency_penalty
      
      def initialize(provider:, model:, temperature: nil, top_p: nil, presence_penalty: nil, frequency_penalty: nil, **kwargs)
        @provider = provider
        @model = model
        @temperature = temperature
        @top_p = top_p
        @presence_penalty = presence_penalty
        @frequency_penalty = frequency_penalty
        @additional_params = kwargs
      end
      
      # Convert model object to parameters that can be passed to LLM adapters
      def to_model_parameters
        params = {
          model: model,
          temperature: temperature,
          top_p: top_p
        }.compact
        
        # Add provider-specific parameters
        case provider.to_s.downcase
        when "openai"
          params[:presence_penalty] = presence_penalty if presence_penalty
          params[:frequency_penalty] = frequency_penalty if frequency_penalty
        when "anthropic"
          # Map to Anthropic-specific parameters if needed
        when "cohere"
          # Map to Cohere-specific parameters if needed
        end
        
        # Add any additional parameters that might be provider-specific
        params.merge!(@additional_params)
        
        params
      end
      
      def self.from_json(json)
        return nil unless json && json["type"] == "constructor"
        
        provider = json["id"][-2] rescue nil # e.g., "openai"
        
        new(
          provider: provider,
          model: json.dig("kwargs", "model"),
          temperature: json.dig("kwargs", "temperature"),
          top_p: json.dig("kwargs", "top_p"),
          presence_penalty: json.dig("kwargs", "presence_penalty"),
          frequency_penalty: json.dig("kwargs", "frequency_penalty")
        )
      end
      
      # Helper methods for checking the provider type
      def openai?
        provider&.downcase == "openai"
      end
      
      def anthropic?
        provider&.downcase == "anthropic"
      end
      
      def cohere?
        provider&.downcase == "cohere"
      end
      
      def to_h
        {
          provider: provider,
          model: model,
          temperature: temperature,
          top_p: top_p,
          presence_penalty: presence_penalty,
          frequency_penalty: frequency_penalty
        }.compact
      end
    end
  end
end
