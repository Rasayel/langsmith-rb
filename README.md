# LangSmith Ruby SDK

A Ruby client for interacting with the LangSmith platform. This SDK allows you to track, monitor, and debug your LLM applications using LangSmith. It's designed to align with the Python LangSmith SDK while maintaining Ruby idioms and conventions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'langsmith-sdk-rb'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install langsmith-sdk-rb
```

## Configuration

You can configure the SDK using environment variables or by using the configuration block:

```ruby
# Using environment variables
ENV["LANGSMITH_API_KEY"] = "your-api-key"
ENV["LANGSMITH_ENDPOINT"] = "https://api.smith.langchain.com" # Optional
ENV["LANGSMITH_PROJECT"] = "default" # Optional
ENV["LANGSMITH_TENANT_ID"] = "your-tenant-id" # Optional

# Or using the configuration block
Langsmith.configure do |config|
  config.api_key = "your-api-key"
  config.api_url = "https://api.smith.langchain.com" # Optional
  config.project_name = "my-project" # Optional, defaults to "default"
end
```

## Core Features

### Tracing

Tracing is a key feature that allows you to monitor and debug your LLM applications. There are several ways to use tracing:

#### Basic Tracing

The simplest way to trace is using the `Langsmith.trace` method:

```ruby
result = Langsmith.trace(
  name: "My Calculation",
  run_type: "chain",
  inputs: { x: 10, y: 20 }
) do |run|
  # Your code here
  sum = 10 + 20
  
  # Return will be captured as outputs
  { sum: sum }
end

# result is { sum: 30 }
```

#### Nested Tracing

You can create nested traces to capture the hierarchy of your application:

```ruby
Langsmith.trace(name: "Parent Operation", run_type: "chain", inputs: { query: "Calculate 2+2" }) do |parent_run|
  # Do some preprocessing
  query = parent_run.inputs[:query]
  
  # Create a child trace
  result = parent_run.trace(
    name: "Child Operation",
    run_type: "llm",
    inputs: { processed_query: "Calculating: #{query}" }
  ) do |child_run|
    # Perform the calculation
    { answer: "2+2=4" }
  end
  
  # Further processing with the result
  { final_answer: result[:answer] }
end
```

#### Method Tracing with Traceable

For class methods, you can use the `Traceable` module to automatically trace methods:

```ruby
class Calculator
  include Langsmith::Traceable
  
  # Make the add method traceable
  traceable :add, run_type: "tool", 
    name: proc { |a, b| "Addition: #{a} + #{b}" },
    metadata: { calculator_type: "basic" }
    
  def add(a, b)
    a + b
  end
end

calc = Calculator.new
result = calc.add(5, 3) # This call is automatically traced
```

#### Important Tracing Behavior

**Return Values Matter**: When using any form of tracing, the return value from your block is crucial for proper trace completion. The SDK uses this return value to automatically end the trace with the appropriate outputs.

```ruby
# Good: Explicitly returning a value from your trace block
Langsmith.trace(name: "My Operation", run_type: "chain") do |run|
  result = perform_operation()
  result # This value will be used as the trace output
end

# Problematic: Not returning a meaningful value
Langsmith.trace(name: "My Operation", run_type: "chain") do |run|
  perform_operation() # If this doesn't return a value, trace won't have proper outputs
  # No explicit return - the trace might not end properly
end
```

This is especially important when creating custom wrapper methods or working with nested traces:

```ruby
# Custom wrapper method - MUST return the yield result
def with_my_custom_tracing(&block)
  Langsmith.trace(name: "Custom Trace") do |run|
    result = yield(run) # Capture the result
    result # Return it so the trace ends properly
  end
end

# Using the wrapper
with_my_custom_tracing do |run|
  { output: "Some result" } # Return value gets properly propagated
end
```

### Run Management

The SDK provides a `RunManager` for advanced run management:

```ruby
# Get the run manager
run_manager = Langsmith.run_manager

# Start a run
run = run_manager.create_run(
  name: "Complex Calculation",
  run_type: "chain",
  inputs: { formula: "2x + y where x=5, y=3" }
)

# Make a child run
child_run = run_manager.create_child_run(
  name: "Calculate 2x",
  run_type: "tool",
  parent_run_id: run.id,
  inputs: { x: 5 }
)

# End the child run with output
run_manager.end_run(
  run=child_run,
  outputs: { result: 10 }
)

# End the parent run
run_manager.end_run(
  run=run,
  outputs: { result: 13 }
)
```

### LLM Wrappers

The SDK includes wrappers for popular LLM providers to automatically trace their calls:

#### OpenAI Wrapper

```ruby
# Wrap an existing OpenAI client
require 'openai'
openai_client = OpenAI::Client.new(access_token: "your-openai-key")

wrapped_client = Langsmith.wrap_openai(openai_client, 
  metadata: { wrapper_version: "1.0" },
  tags: ["openai", "gpt"]
)

# Now all calls are traced
response = wrapped_client.chat(
  parameters: {
    model: "gpt-3.5-turbo",
    messages: [{ role: "user", content: "Hello, world!" }]
  }
)
```

#### Anthropic Wrapper

```ruby
require 'anthropic'
anthropic_client = Anthropic::Client.new(api_key: "your-anthropic-key")

wrapped_client = Langsmith.wrap_anthropic(anthropic_client)

response = wrapped_client.messages(
  model: "claude-2",
  max_tokens: 1000,
  messages: [{ role: "user", content: "Tell me a story." }]
)
```

#### Cohere Wrapper

```ruby
require 'cohere-ruby'
cohere_client = Cohere::Client.new(api_key: "your-cohere-key")

wrapped_client = Langsmith.wrap_cohere(cohere_client)

response = wrapped_client.generate(
  prompt: "Write a poem about programming.",
  model: "command"
)
```

### LangChain Hub Integration

The SDK allows you to work with prompts and models stored in LangChain Hub:

#### Pulling Prompts

```ruby
# Pull a prompt from the Hub
prompt = Langsmith.prompt("hub://my-organization/my-prompt")

# Format the prompt with variables
formatted_prompt = prompt.format(name: "Alice", question: "What is the capital of France?")

# Or pull directly using the hub client
hub = Langsmith.hub
prompt_template = hub.pull_prompt("my-organization/my-prompt")
```

#### Pushing Prompts

```ruby
# Create a prompt template
template = Langsmith::Models::PromptTemplate.new(
  template: "Hello, {{name}}! How can I help you with {{topic}}?",
  input_variables: ["name", "topic"]
)

# Push to Hub
hub = Langsmith.hub
hub.push_prompt("my-organization/greeting-prompt", 
  object: template,
  description: "A simple greeting prompt",
  is_public: false
)
```

### Creating and Managing Feedback

```ruby
client = Langsmith.client

# Create feedback on a run
client.create_feedback(
  run_id: "run-id",
  key: "correctness",
  value: 1,  # Score from 0 to 1
  comment: "This response was accurate"
)

# List feedback for a run
feedback = client.list_run_feedback(run_id: "run-id")

# Create a dataset from existing runs
dataset = client.create_dataset(
  name: "Customer Support Examples",
  description: "Examples of customer support interactions"
)

# Add examples to the dataset
client.create_example(
  inputs: { query: "How do I reset my password?" },
  outputs: { response: "You can reset your password by..." },
  dataset_id: dataset["id"]
)
```

### Chat Models and Tools

The SDK supports chat-based models and tools:

#### Creating Chat Prompts

```ruby
# Create message templates
system_message = Langsmith::Models::MessageTemplate.new(
  role: "system",
  content: "You are a helpful assistant."
)

user_message = Langsmith::Models::MessageTemplate.new(
  role: "user",
  content: "Hello, {{name}}! I have a question about {{topic}}."
)

# Create a chat prompt template
chat_prompt = Langsmith::Models::ChatPromptTemplate.new(
  messages: [system_message, user_message],
  input_variables: ["name", "topic"]
)

# Format the chat prompt
messages = chat_prompt.format(name: "Bob", topic: "Ruby programming")
```

#### Defining Tools

```ruby
# Define a tool
calculator_tool = Langsmith::Models::Tool.new(
  name: "calculator",
  description: "Performs basic arithmetic operations",
  parameters: {
    type: "object",
    properties: {
      operation: {
        type: "string",
        enum: ["add", "subtract", "multiply", "divide"]
      },
      a: { type: "number" },
      b: { type: "number" }
    },
    required: ["operation", "a", "b"]
  },
  handler: lambda do |params|
    case params[:operation]
    when "add"
      params[:a] + params[:b]
    when "subtract"
      params[:a] - params[:b]
    when "multiply"
      params[:a] * params[:b]
    when "divide"
      params[:a] / params[:b]
    end
  end
)

# Use the tool with tracing
Langsmith.trace(name: "Math Operation", run_type: "tool") do |run|
  result = calculator_tool.invoke({
    operation: "add",
    a: 5,
    b: 3
  })
  { result: result }
end
```

## Advanced Usage

### Custom Run Types

You can define custom run types for better organization:

```ruby
Langsmith.trace(
  name: "Data Processing",
  run_type: "data_processor",  # Custom run type
  inputs: { data: [1, 2, 3, 4, 5] }
) do |run|
  processed_data = run.inputs[:data].map { |x| x * 2 }
  { processed_data: processed_data }
end
```

### Session Management

Group related runs using sessions:

```ruby
# Create a session ID
session_id = SecureRandom.uuid

# Use the same session ID for multiple runs
Langsmith.trace(
  name: "User Query Processing",
  session_id: session_id,
  inputs: { query: "What's the weather like?" }
) do |run|
  # Process query
  { result: "It's sunny today" }
end

# Later in the same user session
Langsmith.trace(
  name: "Follow-up Query",
  session_id: session_id,  # Same session ID
  inputs: { query: "What about tomorrow?" }
) do |run|
  # Process follow-up
  { result: "Rain is expected tomorrow" }
end
```

### Thread Safety

The SDK is designed to be thread-safe:

```ruby
# In a multi-threaded environment
threads = 3.times.map do |i|
  Thread.new do
    # Each thread gets its own trace context
    Langsmith.trace(name: "Thread #{i} Operation", inputs: { thread_id: i }) do |run|
      # Thread-specific processing
      { result: "Processed in thread #{i}" }
    end
  end
end

threads.each(&:join)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
