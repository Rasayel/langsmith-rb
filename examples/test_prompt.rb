require "langsmith"
require "dotenv/load"
require "json"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
end

# Create wrapped OpenAI client
openai_client = Langsmith.wrap_openai(access_token: ENV["OPENAI_API_KEY"])

begin
  # Create inputs for our test
  inputs = {
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
  }

  # Create a RunTree instance for the main run
  run_tree = Langsmith::RunTree.new(
    name: "Qualification Agent Test",
    run_type: "chain",
    inputs: inputs
  )

  # Post the run and get the response
  response = run_tree.post
  puts "Created run response:"
  puts JSON.pretty_generate(response)
  puts "Run ID: #{run_tree.id}"

  begin
    # Fetch and format our prompt
    prompt_name = "qualify-agent"
    prompt_json = Langsmith.hub.pull(prompt_name)
    prompt = Langsmith::Models::ChatPromptTemplate.from_json(prompt_json)
    messages = prompt.format(**inputs)

    # Call OpenAI with our wrapped client
    llm_response = openai_client.call(
      messages: messages,
      model: "gpt-4",
      temperature: 0.7,
      parent_run_id: run_tree.id # Link to parent run
    )

    # Extract the assistant's message
    assistant_message = llm_response.dig("choices", 0, "message")
    
    # Update run with outputs and complete
    run_tree.end(
      outputs: { 
        response: assistant_message["content"],
        messages: messages,
        model: llm_response["model"],
        usage: llm_response["usage"]
      }
    )
    run_tree.patch

    puts "\nAssistant's response:"
    puts assistant_message["content"]

  rescue StandardError => e
    # If anything goes wrong, mark the run as failed
    run_tree.end(error: e.message)
    run_tree.patch
    raise
  end

rescue StandardError => e
  puts "Error: #{e.message}"
end
