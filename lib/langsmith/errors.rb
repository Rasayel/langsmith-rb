module Langsmith
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class APIError < Error; end
  class ValidationError < Error; end
end
