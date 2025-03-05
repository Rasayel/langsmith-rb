require "langsmith"
require "dotenv/load"
require "securerandom"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = ENV["LANGSMITH_PROJECT"] || "prompt-from-hub-example"
end

# Conversation manager that leverages prompts from LangSmith Hub
class HubPromptConversation
  include Langsmith::Traceable
  
  attr_reader :system_prompt, :llm, :thread_map, :repo_name
  
  # Initialize with the LangSmith Hub repository name
  def initialize(repo_name:, model: "gpt-3.5-turbo", update_interval: 3600)
    @repo_name = repo_name
    @llm = Langsmith.wrap_openai(access_token: ENV["OPENAI_API_KEY"], model: model)
    @thread_map = {}
    @last_update = Time.now - update_interval  # Force initial fetch
    @update_interval = update_interval  # How often to check for updates (in seconds)
    
    # Initial fetch of the prompt
    refresh_prompt
  end
  
  # Refresh the prompt from LangSmith Hub if needed
  def refresh_prompt
    current_time = Time.now
    
    # Only refresh if update interval has passed
    if current_time - @last_update >= @update_interval
      puts "Fetching latest prompt from LangSmith Hub: #{repo_name}"
      
      begin
        # Trace the prompt fetch operation
        @system_prompt = trace(name: "fetch_hub_prompt", run_type: "tool") do |run|
          prompt_data = Langsmith.client.pull_prompt(repo_name)
          
          # Store metadata about the prompt
          run.update(
            outputs: { 
              prompt_found: !prompt_data.nil?,
              prompt_type: prompt_data["_type"]
            }
          )
          
          # Extract the system prompt from the manifest
          if prompt_data["_type"] == "prompt"
            prompt_data["template"]
          elsif prompt_data["_type"] == "chat"
            # For chat prompts, find the system message
            system_message = prompt_data["messages"].find { |msg| msg["role"] == "system" }
            system_message ? system_message["template"] : "You are a helpful assistant."
          else
            "You are a helpful assistant."
          end
        end
        
        @last_update = current_time
        puts "Prompt updated successfully."
      rescue => e
        puts "Error fetching prompt: #{e.message}"
        # Use a default prompt if fetch fails
        @system_prompt ||= "You are a helpful assistant."
      end
    end
    
    @system_prompt
  end
  
  # Get or create a thread for a given user
  def get_thread(user_id)
    # Create a new thread if one doesn't exist
    @thread_map[user_id] ||= {
      id: SecureRandom.uuid,
      messages: [],
      metadata: { user_id: user_id }
    }
  end
  
  # Process a message for a specific user
  def process_message(user_id, message, context: {})
    # Refresh the prompt if needed
    refresh_prompt
    
    # Get the user's thread
    thread = get_thread(user_id)
    
    # Create a fresh chat instance for this message
    chat = Langsmith::Chat.new(
      llm: @llm,
      thread_id: thread[:id],
      context: context
    )
    
    # Process with internal tracing
    trace(name: "process_hub_prompt_message",
          run_type: "chain", 
          inputs: { message: message },
          metadata: { thread_id: thread[:id], user_id: user_id }) do |run|
      
      # Add user message to thread history
      thread[:messages] << { role: "user", content: message }
      
      # Create the messages array for this request
      messages = []
      
      # Add system message with the fetched prompt
      messages << { role: "system", content: @system_prompt }
      
      # Add conversation history
      messages.concat(thread[:messages])
      
      # Call the LLM with the full message history
      response = chat.call(
        messages,
        name: "Hub Prompt Message"
      )
      
      # Add assistant response to thread history
      thread[:messages] << { role: "assistant", content: response }
      
      # Return the response
      response
    end
  end
  
  # Make the process_message method traceable
  traceable :process_message, run_type: "chain", tags: ["hub_prompt", "conversation"]
end

# Create a conversation manager with a prompt from LangSmith Hub
# Replace 'your-hub-repo/prompt-name' with an actual prompt from your LangSmith account
REPO_NAME = ENV["LANGSMITH_PROMPT_REPO"] || "default/helpful-assistant"
conversation = HubPromptConversation.new(repo_name: "testing-prompt")

# Start our demo
puts "Starting Hub Prompt conversation example"
puts "Using prompt from: #{REPO_NAME}"

# Demo context (optional)
CONTEXT = {
  "app_name" => "LangSmith Ruby SDK",
  "user_preferences" => "Technical, concise responses"
}

# Wrap the entire demo in a parent trace
Langsmith.trace(
  name: "Hub Prompt Conversation Flow",
  run_type: "chain",
  tags: ["example", "hub_prompt"],
  metadata: { "demo_type" => "multiple_users" }
) do |parent_run|
  # Simulate conversations with multiple users
  
  # User 1 conversation thread
  puts "\n=== User 1 conversation ==="
  response = conversation.process_message("user_1", "Hello, can you tell me what LangSmith is?", context: CONTEXT)
  puts "Assistant: #{response}"
  
  response = conversation.process_message("user_1", "What features does it offer for developers?")
  puts "Assistant: #{response}"
  
  # User 2 conversation thread - completely separate thread
  puts "\n=== User 2 conversation ==="
  response = conversation.process_message("user_2", "What's the best way to track my LLM application's performance?", context: CONTEXT)
  puts "Assistant: #{response}"
  
  # Back to User 1 - their history is preserved
  puts "\n=== User 1 conversation (continued) ==="
  response = conversation.process_message("user_1", "Thanks for explaining. How does it compare to other similar tools?")
  puts "Assistant: #{response}"
  
  # Add feedback on one of the responses
  parent_run.add_feedback(
    key: "conversation_quality",
    value: 0.9,
    comment: "Demonstrated proper handling of multiple concurrent threads while maintaining context"
  )
  
  # If you wanted to retrieve runs for this example, you could do:
  # 
  # # Get thread_ids from all the conversations
  # thread_ids = conversation.thread_map.values.map { |thread| thread[:id] }
  # 
  # runs = Langsmith.run_manager.get_runs(
  #   filters: {
  #     filter_tags: ["hub_prompt"],
  #     run_type: "chain",
  #     session_id: thread_ids
  #   },
  #   limit: 10
  # )
  # puts "Found #{runs.size} runs for this example"
  
  # Return final status
  { "status" => "completed" }
end

puts "\nHub Prompt example completed!"
