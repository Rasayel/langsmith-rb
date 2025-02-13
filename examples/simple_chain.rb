require "langsmith"
require "dotenv/load"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
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

# Create a chain with the qualification prompt and tool implementations
chain = Langsmith::Chain.new(
  prompt_name: "qualify-agent",
  llm: Langsmith.wrap_openai(access_token: ENV["OPENAI_API_KEY"]),
  tool_implementations: tool_implementations
)

# Print available tools after first run (tools are loaded when needed)
response = chain.call(
  agent_name: "Alex",
  business_website: "rasayel.io",
  description: "Rasayel helps businesses communicate with their customers",
  products_and_services: "WhatsApp Business API, Team Inbox, Automations",
  primary_language: "English",
  other_languages: "Arabic, Spanish",
  qualification_goals: "Business size, messaging volume, current channels",
  disqualification_topics: "Personal use, no business registration",
  capabilities: "Can use tools: qualify, disqualify, handover",
  question: "Hi, I'm interested in your service but I'm just an individual looking to chat with friends"
)

puts "\nAvailable tools:"
chain.tools.each do |name, tool|
  puts "- #{name}: #{tool.description}"
end

puts "\nAssistant's response:"
puts response
