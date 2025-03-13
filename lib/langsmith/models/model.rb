module Langsmith
  module Models
    class Model < BaseModel
      attr_reader :provider, :model, :temperature, :top_p, :presence_penalty, :frequency_penalty, :max_tokens, :reasoning_effort, :model_kwargs
      
      def initialize(provider:, model:, temperature: nil, top_p: nil, presence_penalty: nil, frequency_penalty: nil, **kwargs)
        @provider = provider
        @model = model
        @temperature = temperature
        @top_p = top_p
        @presence_penalty = presence_penalty
        @frequency_penalty = frequency_penalty
        
        @model_kwargs = kwargs.delete(:model_kwargs) || {}
        
        @max_tokens = kwargs["max_tokens"] || @model_kwargs[:max_tokens] || @model_kwargs["max_tokens"] # For Anthropic
        @reasoning_effort = @model_kwargs[:reasoning_effort] || @model_kwargs["reasoning_effort"] # For OpenAI
        
        @additional_params = kwargs
      end
      
      def to_model_parameters
        params = {}

        params[:model] = model if model
        params[:temperature] = temperature if temperature
        params[:top_p] = top_p if top_p
        

        case provider.to_s.downcase
        when "openai"
          params[:presence_penalty] = presence_penalty if presence_penalty
          params[:frequency_penalty] = frequency_penalty if frequency_penalty
          params[:reasoning_effort] = reasoning_effort if reasoning_effort
        when "anthropic"
          params[:max_tokens] = max_tokens if max_tokens
        when "cohere"
          # Map to Cohere-specific parameters if needed
        end
        
        api_key_patterns = [
          /api_?key/i,    
          /auth/i,         
          /token/i,        
          /secret/i,      
          /credential/i,   
          /password/i     
        ]
        
        # Helper method to check if a key should be filtered
        should_filter = lambda do |key|
          key_str = key.to_s
          api_key_patterns.any? { |pattern| key_str =~ pattern }
        end
        
        if @model_kwargs && !@model_kwargs.empty?
          # Convert all keys to symbols for consistent access
          processed_keys = params.keys.map(&:to_s)
          
          @model_kwargs.each do |key, value|
            # Skip keys we've already processed or should be filtered
            key_str = key.to_s
            next if processed_keys.include?(key_str) || should_filter.call(key_str)
            
            # Add this parameter
            params[key.to_sym] = value
          end
        end
        
        # Add any additional parameters that might be provider-specific
        # following the same deduplication and filtering approach
        if @additional_params && !@additional_params.empty?
          processed_keys = params.keys.map(&:to_s)
          
          @additional_params.each do |key, value|
            key_str = key.to_s
            next if processed_keys.include?(key_str) || should_filter.call(key_str)
            
            params[key.to_sym] = value
          end
        end
        
        params
      end
      
      def self.from_json(json)
        return nil unless json && json["type"] == "constructor"
        
        provider = json["id"][-2] rescue nil # e.g., "openai"
        kwargs = json.dig("kwargs") || {}
        
        new(
          provider: provider,
          model: kwargs["model"],
          temperature: kwargs["temperature"],
          top_p: kwargs["top_p"],
          presence_penalty: kwargs["presence_penalty"],
          frequency_penalty: kwargs["frequency_penalty"],
          model_kwargs: kwargs["model_kwargs"],
          **kwargs
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
        base = {
          provider: provider,
          model: model,
          temperature: temperature,
          top_p: top_p,
          presence_penalty: presence_penalty,
          frequency_penalty: frequency_penalty
        }
        
        # Add provider-specific parameters if present
        case provider&.downcase
        when "openai"
          base[:reasoning_effort] = reasoning_effort if reasoning_effort
        when "anthropic"
          base[:max_tokens] = max_tokens if max_tokens
        end
        
        # Add any model_kwargs if they exist
        base[:model_kwargs] = model_kwargs if model_kwargs && !model_kwargs.empty?
        
        base.compact
      end
    end
  end
end
