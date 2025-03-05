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
  prompt_name = "testing-prompt"
  puts "Fetching prompt '#{prompt_name}' from your workspace..."
  
  prompt = Langsmith::Models::ChatPromptTemplate.pull(prompt_name)

  # Example usage of the prompt
  messages = prompt.format(
    objectives: "Example 1, Example 2",
    disqualification_criteria: "Example 3, Example 4"
  )

  puts "\nFormatted Messages:"
  puts JSON.pretty_generate(messages)
rescue Langsmith::APIError => e
  puts "Error fetching prompt: #{e.message}"
end
