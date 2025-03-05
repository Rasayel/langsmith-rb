require "langsmith"
require "dotenv/load"
require "json"

# Configure Langsmith with your API key
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
end

# Create a new chat prompt template with tools
system_message = Langsmith::Models::SystemMessageTemplate.new(
  prompt: Langsmith::Models::PromptTemplate.new(
    template: "You are a helpful assistant. You have access to the following tools:\n{tools_desc}",
    input_variables: ["tools_desc"]
  )
)

human_message = Langsmith::Models::HumanMessageTemplate.new(
  prompt: Langsmith::Models::PromptTemplate.new(
    template: "User query: {query}",
    input_variables: ["query"]
  )
)

# Create a tool for searching a knowledge base
search_tool = Langsmith::Models::Tool.new(
  name: "search_knowledge_base",
  description: "Search the knowledge base for information",
  parameters: {
    "type" => "object",
    "properties" => {
      "query" => {
        "type" => "string",
        "description" => "The search query"
      }
    },
    "required" => ["query"]
  }
)

# Create a tool for retrieving customer data
customer_tool = Langsmith::Models::Tool.new(
  name: "get_customer_info",
  description: "Get information about a customer",
  parameters: {
    "type" => "object",
    "properties" => {
      "customer_id" => {
        "type" => "string",
        "description" => "The customer ID"
      },
      "include_orders" => {
        "type" => "boolean",
        "description" => "Whether to include order history"
      }
    },
    "required" => ["customer_id"]
  }
)

# Create the chat prompt template
chat_template = Langsmith::Models::ChatPromptTemplate.new(
  messages: [system_message, human_message],
  input_variables: ["tools_desc", "query"],
  tools: [search_tool, customer_tool]
)

# Create a model
model = Langsmith::Models::Model.new(
  provider: "openai",
  model: "gpt-4",
  temperature: 0.7,
  top_p: 0.95
)

# Create the prompt with the template and model
prompt = Langsmith::Models::Prompt.new(
  template: chat_template,
  model: model,
  tools: [search_tool, customer_tool]
)

# Format the prompt to test it
tools_desc = "search_knowledge_base: Search for information\nget_customer_info: Get customer details"
messages = prompt.format(tools_desc: tools_desc, query: "Find information about customer ID: C12345")

puts "Formatted Messages:"
messages.each do |message|
  puts "\nRole: #{message[:role]}"
  puts "Content: #{message[:content]}"
end

puts "\nModel Information:"
puts "Provider: #{prompt.model.provider}"
puts "Model: #{prompt.model.model}"
puts "Temperature: #{prompt.model.temperature}"

puts "\nTools Information:"
prompt.tools.each do |tool|
  puts "\nTool: #{tool.name}"
  puts "Description: #{tool.description}"
  puts "OpenAI format: #{JSON.pretty_generate(tool.to_openai_tool)}"
end

# Push the prompt to LangSmith Hub if enabled
if ENV["PUSH_PROMPT"] == "true"
  repo_name = "ruby-customer-assistant-#{Time.now.to_i}"
  puts "\nPushing prompt to LangSmith Hub as '#{repo_name}'..."
  
  begin
    url = prompt.push(
      repo_name,
      description: "A customer assistant prompt with tools",
      readme: "# Customer Assistant\nThis prompt helps assist customers by providing tools to search the knowledge base and retrieve customer information.",
      tags: ["ruby-sdk", "customer-service", "tools"],
      is_public: false
    )
    
    puts "Prompt successfully pushed to LangSmith Hub!"
    puts "View it at: #{url}"
  rescue Langsmith::APIError => e
    puts "Error pushing prompt: #{e.message}"
  end
end
