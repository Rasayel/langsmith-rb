require "langsmith"
require "dotenv/load"
require "securerandom"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = ENV["LANGSMITH_PROJECT"] || "chat-example"
end

# Create a simple qualified conversation wrapper
class QualificationConversation
  include Langsmith::Traceable
  
  attr_reader :thread_id, :llm, :context
  
  def initialize(thread_id: nil, context: {})
    @thread_id = thread_id || SecureRandom.uuid
    @llm = Langsmith.wrap_openai(access_token: ENV["OPENAI_API_KEY"], model: "gpt-3.5-turbo")
    @context = context
    @session_id = @thread_id
    @messages = [] # Store conversation history
  end
  
  def process_message(message)
    # Create a fresh chat instance for this message
    chat = Langsmith::Chat.new(
      llm: @llm,
      thread_id: @thread_id,
      context: @context.merge("question" => message),
      parent_run_id: Langsmith.current_run_tree&.id  # Link to parent run if one exists
    )
    
    # Process with internal tracing
    trace(name: "process_message", run_type: "chain", inputs: { message: message }) do |run|
      puts "Processing message: #{message}"
      
      # First analyze the message intent
      intent = trace(name: "analyze_intent", run_type: "tool", inputs: { message: message }) do |intent_run|
        # We could call an actual classifier here, but we'll mock it
        intent = case message.downcase
          when /pricing|cost|price/
            "pricing_inquiry"
          when /register|business|company/
            "business_registration"
          else
            "general_inquiry"
          end
        
        puts "Detected intent: #{intent}"
        
        # Add some feedback to this intent detection
        intent_run.add_feedback(
          key: "accuracy", 
          value: 0.9, 
          comment: "Intent classification looks accurate"
        )
        
        # Return the intent
        { intent: intent }
      end
      
      # Add user message to history
      @messages << { role: "user", content: message }
      
      # Process the message with history based on intent
      response = chat.call(
        @messages,
        name: "Qualification Message: #{intent[:intent]}"  # Name based on intent
      )
      
      # Add assistant response to history
      @messages << { role: "assistant", content: response }
      
      # Add feedback on the overall response quality
      run.add_feedback(
        key: "response_quality",
        value: 0.85,
        comment: "Good qualification response"
      )
      
      # Return the response
      response
    end
  end
  
  # Make the process_message method traceable
  traceable :process_message, run_type: "chain", tags: ["qualification", "conversation"]
end

# Initial context that doesn't need to be repeated
AGENT_CONTEXT = {
  "agent_name" => "Alex",
  "business_website" => "rasayel.io",
  "description" => "Rasayel helps businesses communicate with their customers",
  "products_and_services" => "WhatsApp Business API, Team Inbox, Automations",
  "primary_language" => "English",
  "other_languages" => "Arabic, Spanish",
  "qualification_goals" => "Business size, messaging volume, current channels",
  "disqualification_topics" => "Personal use, no business registration",
  "capabilities" => "Can use tools: qualify, disqualify, handover"
}

# Create a new conversation instance
conversation = QualificationConversation.new(context: AGENT_CONTEXT)
thread_id = conversation.thread_id

# Start our demo
puts "Starting qualification conversation example"
puts "Thread ID: #{thread_id}"

# Wrap the entire conversation in a parent trace
Langsmith.trace(
  name: "Qualification Conversation Flow",
  run_type: "chain",
  tags: ["example", "conversation"],
  metadata: { 
    "thread_id" => thread_id, 
    "session_id" => thread_id, 
    "string_key" => "string_value", 
    something: "symbol_key_value", 
    nested: { "level" => 1, sublevel: 2 },
    number: 42,
    boolean: true
  }
) do |parent_run|
  # First message: Initial inquiry
  puts "\n=== First webhook: Initial inquiry ==="
  response = conversation.process_message("Hi, I'm interested in your service but I'm just an individual looking to chat with friends")
  puts "Assistant response: #{response}"
  
  # Second message: Follow-up about business
  puts "\n=== Second webhook: Follow-up about business ==="
  response = conversation.process_message("What if I register a business? Would that help? I'm thinking of starting a small online shop.")
  puts "Assistant response: #{response}"
  
  # Third message: Business details
  puts "\n=== Third webhook: Business details ==="
  response = conversation.process_message("I'm planning to start a small e-commerce business selling handmade jewelry. We expect about 100 customers initially and would need to communicate with them about orders and shipping.")
  puts "Assistant response: #{response}"
  
  # Fourth message: Pricing inquiry
  puts "\n=== Fourth webhook: Pricing inquiry ==="
  response = conversation.process_message("Great! What would the pricing look like for my business size?")
  puts "Assistant response: #{response}"
  
  # Add final feedback on the overall conversation
  parent_run.add_feedback(
    key: "conversation_quality",
    value: 0.9,
    comment: "Conversation flow was smooth and appropriate"
  )
  
  # Return final status
  { "thread_id" => thread_id, "status" => "completed" }
end

puts "\nChat example completed!"
