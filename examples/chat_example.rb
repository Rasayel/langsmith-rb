require "langsmith"
require "dotenv/load"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = "chat-example"
end

# In a real app, this would be stored in your database
# and retrieved when a new message comes in
THREAD_ID = "550e8400-e29b-41d4-a716-446655440000"

# Initial context that doesn't need to be repeated
# In a real app, this would be loaded from your database
AGENT_CONTEXT = {
  "agent_name" => "Alex",
  "business_website" => "rasayel.io",
  "description" => "Rasayel helps businesses communicate with their customers",
  "products_and_services" => "WhatsApp Business API, Team Inbox, Automations",
  "primary_language" => "English",
  "other_languages" => "Arabic, Spanish",
  "qualification_goals" => "Business size, messaging volume, current channels",
  "disqualification_topics" => "Personal use, no business registration",
  "capabilities" => "Can use tools: qualify, disqualify, handover",
  "question" => nil  # This will be set for each message
}

# Create a run tree for the entire conversation
CONVERSATION_RUN = Langsmith::RunTree.new(
  name: "Qualification Chat",
  run_type: "chain",
  inputs: {},
  metadata: {
    "thread_id" => THREAD_ID,
    "session_id" => THREAD_ID
  }
)
CONVERSATION_RUN.post

def handle_incoming_message(message, thread_id, context)
  puts "\n=== New webhook received ==="
  puts "Thread ID: #{thread_id}"
  puts "User message: #{message}"
  
  # Create a fresh chat instance
  # In a real app, this would happen in a new process/webhook
  chat = Langsmith::Chat.new(
    llm: Langsmith.wrap_openai(access_token: ENV["OPENAI_API_KEY"]),
    thread_id: thread_id,
    context: context.merge("question" => message),
    parent_run_id: CONVERSATION_RUN.id  # Link all messages to the same conversation
  )
  
  # Process the message with history
  response = chat.call(
    message, 
    get_history: true,
    name: "Qualification Message"  # Give each message a meaningful name
  )
  puts "\nAssistant response:"
  puts response
  response
end

# Simulate a conversation over webhooks
puts "\n=== First webhook: Initial inquiry ==="
handle_incoming_message(
  "Hi, I'm interested in your service but I'm just an individual looking to chat with friends",
  THREAD_ID,
  AGENT_CONTEXT
)

puts "\n=== Second webhook: Follow-up about business ==="
handle_incoming_message(
  "What if I register a business? Would that help? I'm thinking of starting a small online shop.",
  THREAD_ID,
  AGENT_CONTEXT
)

puts "\n=== Third webhook: Business details ==="
handle_incoming_message(
  "I'm planning to start a small e-commerce business selling handmade jewelry. We expect about 100 customers initially and would need to communicate with them about orders and shipping.",
  THREAD_ID,
  AGENT_CONTEXT
)

puts "\n=== Fourth webhook: Pricing inquiry ==="
handle_incoming_message(
  "Great! What would the pricing look like for my business size?",
  THREAD_ID,
  AGENT_CONTEXT
)

# End the conversation run
CONVERSATION_RUN.end(
  outputs: {
    "thread_id" => THREAD_ID,
    "status" => "completed"
  }
)
CONVERSATION_RUN.patch
