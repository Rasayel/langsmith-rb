require "langsmith"
require "dotenv/load"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
end

# Pull a prompt that has tools defined
prompt_json = Langsmith.hub.pull("qualify-agent", include_model: true)
prompt = Langsmith::Models::ChatPromptTemplate.from_json(prompt_json)

puts "\nPrompt Tools:"
prompt.tools.each do |tool|
  puts "\n#{tool}"
end

# Format the prompt - tools will be included in system message
messages = prompt.format(
  agent_name: "Alex",
  business_website: "example.com",
  description: "Example business",
  products_and_services: "Example products",
  primary_language: "English",
  other_languages: "",
  qualification_goals: "Example goals",
  disqualification_topics: "Example disqualifications",
  capabilities: "Example capabilities",
  question: "Hi there!"
)

puts "\nFormatted Messages:"
messages.each do |message|
  puts "\n#{message[:role].upcase}:"
  puts message[:content]
end
