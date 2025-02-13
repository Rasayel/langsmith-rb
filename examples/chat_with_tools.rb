require "langsmith"
require "dotenv/load"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = "chat-with-tools"
end

# Define tool implementations
tool_implementations = {
  # Qualify tool implementation
  "qualify" => ->(input, **kwargs) {
    score = rand(1..100)  # In a real app, this would use actual qualification logic
    { 
      qualified: score > 70,
      score: score,
      reason: "Example qualification based on random score"
    }
  },

  # Disqualify tool implementation
  "disqualify" => ->(input, **kwargs) {
    { 
      disqualified: true,
      reason: input["reason"] || "No specific reason provided"
    }
  },

  # Handover tool implementation
  "handover" => ->(input, **kwargs) {
    {
      success: true,
      assigned_to: "sales_team",
      notes: input["notes"] || "Standard handover"
    }
  }
}

# Create a chat instance with tool implementations
chat = Langsmith::Chat.new(
  llm: Langsmith.wrap_openai(
    access_token: ENV["OPENAI_API_KEY"],
    model: "gpt-4-turbo-preview"  # Model that supports tool calls
  ),
  tool_implementations: tool_implementations
)

# Print available tools
puts "Available tools:"
chat.tools.each do |name, tool|
  puts "- #{name}: #{tool.description}"
end

# Process a message that might use tools
response = chat.call(
  "I need help qualifying a lead for our business. They're asking about pricing.",
  name: "Lead Qualification"
)

puts "\nAssistant's response:"
puts response
