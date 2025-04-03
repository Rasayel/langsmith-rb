module Langsmith
  # Container module for error classes used throughout the gem
  # This structure ensures compatibility with Rails' Zeitwerk autoloader
  module Errors
    # Base error class for all Langsmith-specific errors
    class Error < StandardError
    end
    
    # Raised when there is an issue with the configuration
    class ConfigurationError < Error; end
    
    # Raised when there is an error communicating with the API
    class APIError < Error; end
    
    # Raised when there is an error validating input data
    class ValidationError < Error; end

    # Raised when invalid arguments are provided to a method
    class ArgumentError < Error; end
  end
  
  # Define top-level error classes for backward compatibility
  # These are aliased to the module versions for consistent API
  Error = Errors::Error
  ConfigurationError = Errors::ConfigurationError
  APIError = Errors::APIError
  ValidationError = Errors::ValidationError
  ArgumentError = Errors::ArgumentError
end
