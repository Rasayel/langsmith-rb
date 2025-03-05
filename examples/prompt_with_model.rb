require "langsmith"
require "dotenv/load"
require "json"

# Configure Langsmith with your API key
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
end

begin
  # Pull a prompt from the hub with include_model set to true
  prompt_name = "qualify-agent" # Replace with your prompt name
  puts "Fetching prompt '#{prompt_name}' with model information..."
  
  # You can pull a prompt using the Prompt class
  prompt = Langsmith::Models::Prompt.pull(prompt_name, include_model: true)
  # Or using the convenience method on the Langsmith module
  # prompt = Langsmith.prompt(prompt_name, include_model: true)

  # Display model information if it exists
  if prompt.has_model?
    puts "\nModel Information:"
    puts "Provider: #{prompt.model.provider}"
    puts "Model: #{prompt.model.model}"
    puts "Temperature: #{prompt.model.temperature}"
    puts "Top P: #{prompt.model.top_p}"
    
    # Get model parameters 
    puts "\nModel Parameters for LLM:"
    puts JSON.pretty_generate(prompt.model.to_model_parameters)
    
    # Check provider-specific properties
    if prompt.model.openai?
      puts "\nThis is an OpenAI model"
    elsif prompt.model.anthropic?
      puts "\nThis is an Anthropic model"
    elsif prompt.model.cohere?
      puts "\nThis is a Cohere model"
    end
  else
    puts "\nNo model information found in the prompt."
  end

  # Display tool information if it exists
  if prompt.has_tools?
    puts "\nTools Information:"
    puts "Number of tools: #{prompt.tools.length}"
    puts "Tool names: #{prompt.tool_names.join(', ')}"
    
    # Display details for each tool
    prompt.tools.each_with_index do |tool, index|
      puts "\nTool #{index + 1}: #{tool.name}"
      puts "Description: #{tool.description}"
      puts "OpenAI tool format:"
      puts JSON.pretty_generate(tool.to_openai_tool)
    end
    
    # Get a specific tool by name
    if qualify_tool = prompt.get_tool("qualify")
      puts "\nQualify Tool Details:"
      puts qualify_tool.to_s
    end
  else
    puts "\nNo tools found in the prompt."
  end

  # Format the prompt with necessary variables
  messages = prompt.format(
    config: {
      context: {
        agent_name: "Alex",
        business_website: "example.com",
        description: "Example business description",
        products_services: {
          items: "Product 1, Product 2"
        },
        languages: {
          primary: "English",
          others: "Spanish, French"
        }
      },
      goals: {
        data_collection_fields: "Business name, Contact person, Email, Number of employees",
        general_disqualification_topics: "Non-business inquiries, Companies with less than 5 employees"
      }
    }
  )

  puts "\nFormatted Messages:"
  messages.each_with_index do |message, index|
    puts "\nMessage #{index + 1} - Role: #{message[:role]}"
    puts "Content: #{message[:content][0..150]}..." # Truncated for display
  end

  # Demonstrate how to push a prompt to the Hub
  if ENV["DEMO_PUSH_PROMPT"] == "true"
    puts "\nPushing prompt to the Hub..."
    # For demo purposes, we're pushing the same prompt we pulled
    # In a real scenario, you might modify the prompt first
    repo_name = "my-#{prompt_name}-copy"
    url = prompt.push(
      repo_name,
      description: "A copy of the #{prompt_name} prompt",
      readme: "# #{prompt_name} Copy\nThis is a demo of pushing a prompt to LangSmith Hub.",
      tags: ["demo", "ruby-sdk"],
      is_public: false # Keep it private
    )
    puts "Prompt pushed successfully!"
    puts "View the prompt at: #{url}"
  end
rescue Langsmith::APIError => e
  puts "Error: #{e.message}"
end
