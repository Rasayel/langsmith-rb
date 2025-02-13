require "langsmith"
require "dotenv/load"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
end

# Create an OpenAI client wrapper
llm = Langsmith.wrap_openai(
  access_token: ENV["OPENAI_API_KEY"],
  model: "gpt-3.5-turbo"
)

# Make a simple call
response = llm.call(
  messages: [
    { role: "user", content: "Say hello!" }
  ]
)

puts "\nAssistant's response:"
puts response.dig("choices", 0, "message", "content")
