require "bundler/setup"
require "langsmith"
require "webmock/rspec"
require "openai"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configure WebMock
  WebMock.disable_net_connect!(allow_localhost: true)

  config.before(:each) do
    # Set up OpenAI configuration for testing
    ENV["OPENAI_ACCESS_TOKEN"] = "test_openai_key"
    
    # Mock OpenAI client to avoid actual initialization
    allow(OpenAI::Client).to receive(:new).and_return(double)
    
    # Set up Langsmith configuration for testing
    allow(Langsmith).to receive(:configuration).and_return(
      double(
        project_name: "test_project",
        api_url: "https://api.smith.langchain.com",
        api_key: "test_api_key"
      )
    )
  end

  config.after(:each) do
    ENV.delete("OPENAI_ACCESS_TOKEN")
  end
end

# Helper method for converting string keys to symbols in hashes
def symbolize_hash(hash)
  case hash
  when Hash
    hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize_hash(v) }
  when Array
    hash.map { |item| symbolize_hash(item) }
  else
    hash
  end
end

def stub_langsmith_request(method, path, response_body = {}, status = 200)
  stub_request(method, "https://api.smith.langchain.com#{path}")
    .to_return(
      status: status,
      body: response_body.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end
