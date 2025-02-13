require "langsmith"
require "dotenv/load"
require "json"

# Configure Langsmith with your API key
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
end

begin
  # Try to fetch a prompt from the current workspace
  # Just provide the name of the prompt, like "qualify-agent"
  prompt_name = "qualify-agent"
  puts "Fetching prompt '#{prompt_name}' from your workspace..."
  
  prompt_json = Langsmith.hub.pull(prompt_name)
  prompt = Langsmith::Models::ChatPromptTemplate.from_json(prompt_json)

  # Example usage of the prompt
  messages = prompt.format(
    agent_name: "Alex",
    business_website: "rasayel.io",
    description: "Rasayel helps businesses communicate with their customers",
    products_and_services: "WhatsApp Business API, Team Inbox, Automations",
    primary_language: "English",
    other_languages: "Arabic, Spanish",
    qualification_goals: "Business size, messaging volume, current channels",
    disqualification_topics: "Personal use, no business registration",
    capabilities: "Can use tools: qualify, disqualify, handover",
    question: "Hi, I'm interested in your service"
  )

  puts "\nFormatted Messages:"
  puts JSON.pretty_generate(messages)
rescue Langsmith::APIError => e
  puts "Error fetching prompt: #{e.message}"
end
