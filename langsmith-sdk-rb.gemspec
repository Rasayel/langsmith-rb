lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "langsmith/version"

Gem::Specification.new do |spec|
  spec.name          = "langsmith-sdk-rb"
  spec.version       = Langsmith::VERSION
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "Ruby SDK for LangSmith"
  spec.description   = "Ruby client for interacting with the LangSmith platform"
  spec.homepage      = "https://github.com/yourusername/langsmith-sdk-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files         = Dir.glob("{lib,spec}/**/*") + %w[README.md LICENSE.txt]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "zeitwerk", "~> 2.6"
  spec.add_dependency "ruby-openai", "~> 6.1"
  spec.add_dependency "anthropic", "~> 0.3"
  spec.add_dependency "cohere-ruby", "~> 0.2"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "rubocop", "~> 1.50"
end
