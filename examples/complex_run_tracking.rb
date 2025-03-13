#!/usr/bin/env ruby
# frozen_string_literal: true

require "langsmith"
require "logger"
require "securerandom"
require "dotenv/load"


# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = ENV["LANGSMITH_PROJECT"] || "ruby_sdk_example"
end

# Set up logger
logger = Logger.new($stdout)
logger.level = Logger::INFO

# Simple LLM class that mocks a language model interaction
class MockLLM
  include Langsmith::Traceable

  def generate(prompt)
    # Simulate a small delay like a real API call
    sleep(0.3)
    "This is a response to: #{prompt}"
  end
  
  # Make the generate method traceable
  traceable :generate, run_type: "llm", tags: ["mock", "llm"]
end

# A simple chained LLM conversation
class SimpleConversation
  include Langsmith::Traceable

  def initialize
    @llm = MockLLM.new
    @logger = Logger.new($stdout)
    @session_id = SecureRandom.uuid
  end

  # This method handles a full conversation flow
  def chat(user_input)
    result = {}
    
    # First trace - analyze the input
    trace(name: "analyze_input", run_type: "tool", inputs: { user_input: user_input }) do |run|
      puts("Analyzing user input: #{user_input}")
      
      # Create a follow-up question
      followup = "How can I help with your question about #{user_input}?"
      
      # Return analysis result
      { followup: followup }
    end
    
    # Second trace - generate initial response
    first_response = trace(name: "initial_response", run_type: "chain", inputs: { user_input: user_input }) do |run|
      puts("Generating initial response")
      
      # Generate with our mock LLM
      response = @llm.generate(user_input)
      
      # Add some feedback to this run
      run.add_feedback(key: "relevance", value: 0.9, comment: "Highly relevant response")
      
      # Return the response
      { response: response }
    end
    
    result[:initial_response] = first_response[:response]
    
    # Third trace - create a follow-up
    followup = trace(name: "generate_followup", run_type: "chain", inputs: { initial_response: first_response[:response] }) do |run|
      puts("Generating followup")
      
      followup_response = @llm.generate("Create a follow-up question based on: #{first_response[:response]}")
      
      # Add some feedback to this run too
      run.add_feedback(key: "helpfulness", value: 0.8, comment: "Good follow-up")
      
      { followup: followup_response }
    end
    
    result[:followup] = followup[:followup]
    
    # Return the complete result
    result
  end
  
  # Make the chat method traceable
  traceable :chat, run_type: "chain", tags: ["conversation"]
end

# Demonstrate using RunManager to work with runs
def demonstrate_run_manager
  puts "===== Run Manager Operations ====="
  
  run_manager = Langsmith::RunManager.new
  
  # List the most recent runs
  recent_runs = run_manager.get_runs(limit: 5)
  puts "Recent runs:"
  recent_runs.each do |run|
    puts "  - #{run['id']}: #{run['name']} (#{run['run_type']})"
  end
  
  # If we have any runs, examine one more closely
  if recent_runs.any?
    run = recent_runs.first
    puts("\nExamining run: #{run['name']} (#{run['id']})")
    
    # Get feedback for the run
    feedback = run_manager.get_feedback(run_id: run['id'])
    if feedback.any?
      puts("Feedback for this run:")
      feedback.each do |fb|
        puts("  - #{fb['key']}: #{fb['value']} (#{fb['comment']})")
      end
    else
      puts("No feedback for this run yet")
      
      # Add some feedback
      run_manager.add_feedback(
        run_id: run['id'],
        key: "quality",
        value: 0.95,
        comment: "Excellent run from our demonstration"
      )
      puts("Added feedback to the run")
    end
    
    # Get the run tree if it's a parent
    if run['child_run_ids']&.any?
      puts("\nThis is a parent run with #{run['child_run_ids'].size} children")
      tree = run_manager.get_run_tree(run['id'])
      puts("Run tree successfully retrieved")
    end
  end
end

# Main execution
puts("Starting complex run tracking example")

conversation = SimpleConversation.new

# Create a top-level trace to group everything
Langsmith.trace(name: "conversation_flow", run_type: "chain", tags: ["example"]) do |parent_run|
  # Process a user query inside the parent trace
  result = conversation.chat("How does tracing work in LangSmith?")
  
  puts("Initial response: #{result[:initial_response]}")
  puts("Follow-up: #{result[:followup]}")
  
  # Add feedback to the parent run
  parent_run.add_feedback(
    key: "overall_quality",
    value: 0.9,
    comment: "This conversation trace is well structured"
  )
  
  # Return the final result
  result
end

# Demonstrate run manager operations
demonstrate_run_manager()

puts("Complex example completed!")
