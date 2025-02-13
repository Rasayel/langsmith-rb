require "langsmith"
require "dotenv/load"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = "chat-example-providers"
end

# Create chats for each provider
openai_chat = Langsmith::Chat.new(
  llm: Langsmith.wrap_openai(access_token: ENV["OPENAI_API_KEY"]),
  thread_id: "openai-thread-1"
)

anthropic_chat = Langsmith::Chat.new(
  llm: Langsmith.wrap_anthropic(access_token: ENV["ANTHROPIC_API_KEY"]),
  thread_id: "anthropic-thread-1"
)

cohere_chat = Langsmith::Chat.new(
  llm: Langsmith.wrap_cohere(api_key: ENV["COHERE_API_KEY"]),
  thread_id: "cohere-thread-1"
)

# Test each provider
[
  ["OpenAI", openai_chat],
  ["Anthropic", anthropic_chat],
  ["Cohere", cohere_chat]
].each do |provider, chat|
  puts "\nTesting #{provider}..."
  
  # First message
  puts "Sending first message..."
  response = chat.call(
    "Hi, I'm interested in your service but I'm just an individual looking to chat with friends"
  )
  puts "#{provider}: #{response}"

  # Follow-up with history
  puts "\nSending follow-up message..."
  response = chat.call(
    "What if I register a business? Would that help?",
    get_history: true
  )
  puts "#{provider}: #{response}"
end
