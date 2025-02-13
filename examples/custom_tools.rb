require "langsmith"
require "dotenv/load"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = "custom-tools"
end

# Load the prompt
prompt_json = Langsmith.hub.pull("qualify-agent")
prompt = Langsmith::Models::ChatPromptTemplate.from_json(prompt_json)

# Define custom tool schemas
custom_tools = [
  {
    name: "check_subscription",
    description: "Check if a business has an active subscription for a specific channel",
    parameters: {
      type: "object",
      properties: {
        business_id: {
          type: "string",
          description: "ID of the business to check"
        },
        channel: {
          type: "string",
          description: "Channel to check subscription for",
          enum: ["whatsapp", "messenger", "instagram", "telegram"]
        }
      },
      required: ["business_id", "channel"]
    }
  },
  {
    name: "check_message_volume",
    description: "Check the monthly message volume for a business across all channels",
    parameters: {
      type: "object",
      properties: {
        business_id: {
          type: "string",
          description: "ID of the business to check"
        },
        months: {
          type: "integer",
          description: "Number of months to look back",
          default: 1
        }
      },
      required: ["business_id"]
    }
  }
]

# Define tool implementations
tool_implementations = {
  # Custom tools
  "check_subscription" => ->(input, **kwargs) {
    channel = input["channel"]
    business_id = input["business_id"]
    
    {
      has_subscription: true,
      channel: channel,
      business_id: business_id,
      subscription_type: "premium",
      seats: 10,
      expires_at: (Time.now + 30*24*60*60).iso8601
    }
  },
  "check_message_volume" => ->(input, **kwargs) {
    {
      total_messages: 15000,
      by_channel: {
        whatsapp: 10000,
        messenger: 3000,
        instagram: 2000
      },
      months: input["months"] || 1,
      average_response_time: "2h 15m"
    }
  }
}

# Create a chat instance with tools
chat = Langsmith::Chat.new(
  llm: Langsmith.wrap_openai(
    access_token: ENV["OPENAI_API_KEY"],
    model: "gpt-4-turbo-preview"
  ),
  tool_implementations: tool_implementations,
  prompt: prompt,
  custom_tools: custom_tools
)

# Print available tools
puts "Available tools:"
chat.tools.each do |name, tool|
  puts "- #{name}: #{tool.description}"
end

# Call chat with prompt and context
response = chat.call(
  prompt,
  name: "Lead Qualification with Custom Tools",
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

puts "\nAssistant's response:"
puts response
