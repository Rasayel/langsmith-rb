#!/usr/bin/env ruby
# frozen_string_literal: true

require "langsmith"
require "logger"

# Configure Langsmith
Langsmith.configure do |config|
  config.api_key = ENV["LANGSMITH_API_KEY"]
  config.project_name = ENV["LANGSMITH_PROJECT"] || "ruby_sdk_example"
end

# Set up logger
logger = Logger.new($stdout)
logger.level = Logger::INFO

# Create a simple calculator class with traceable methods
class Calculator
  include Langsmith::Traceable
  
  def initialize
    @logger = Logger.new($stdout)
  end
  
  # Make the add method traceable
  traceable :add, run_type: "tool", tags: ["calculator", "addition"]
  def add(a, b)
    @logger.info("Adding #{a} + #{b}")
    a + b
  end
  
  # Make the subtract method traceable
  traceable :subtract, run_type: "tool", tags: ["calculator", "subtraction"]
  def subtract(a, b)
    @logger.info("Subtracting #{a} - #{b}")
    a - b
  end
  
  # Manual tracing example
  def multiply(a, b)
    trace(name: "multiply", run_type: "tool", inputs: { a: a, b: b }) do |run|
      @logger.info("Multiplying #{a} * #{b}")
      result = a * b
      @logger.info("Result: #{result}")
      result
    end
  end
end

# Example usage of the Calculator
logger.info("Starting calculator example")

# Create a calculator
calc = Calculator.new

# Trace a top-level operation
Langsmith.trace(name: "calculator_operations", run_type: "chain", tags: ["example"]) do |run|
  # These operations will be nested under the top-level trace
  sum = calc.add(5, 3)
  logger.info("Sum: #{sum}")
  
  diff = calc.subtract(10, 4)
  logger.info("Difference: #{diff}")
  
  product = calc.multiply(6, 7)
  logger.info("Product: #{product}")
  
  # Let's create another level of nesting
  run.trace(name: "complex_calculation", run_type: "chain", inputs: { sum: sum, diff: diff, product: product }) do |nested_run|
    # Perform a complex calculation using the previous results
    final_result = sum + diff * product
    logger.info("Complex result: #{final_result}")
    
    # Return the result, which will be used as the output for this run
    { final_result: final_result }
  end
  
  # Return a summary of all operations
  {
    addition: sum,
    subtraction: diff,
    multiplication: product,
    complex: final_result
  }
end

# Using the RunManager to query runs
logger.info("Querying runs using RunManager")
run_manager = Langsmith::RunManager.new

# Get recent runs
recent_runs = run_manager.get_runs(
  filters: { run_type: "chain" },
  limit: 5
)

logger.info("Recent chain runs:")
recent_runs.each do |run|
  logger.info("  - #{run[:name]} (#{run[:id]})")
end

logger.info("Example completed!")
