# LangSmith Ruby SDK

A Ruby client for interacting with the LangSmith platform. This SDK allows you to track, monitor and debug your LLM applications using LangSmith.

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
ENV["LANGSMITH_TENANT_ID"] = "your-tenant-id" # Optional

# Or using the configuration block
Langsmith.configure do |config|
  config.api_key = "your-api-key"
  config.api_url = "https://api.smith.langchain.com" # Optional
end
```

## Usage

### Creating a Run

```ruby
client = Langsmith.client

# Create a new run
run = client.create_run(
  name: "My Test Run",
  run_type: "chain",
  inputs: { prompt: "Hello, world!" },
  tags: ["test"],
  metadata: { model: "gpt-3.5-turbo" }
)

# Update the run with outputs
client.update_run(
  run_id: run["id"],
  outputs: { response: "Hi there!" },
  end_time: Time.now
)
```

### Listing Runs

```ruby
# List runs for a project
runs = client.list_runs(
  project_name: "my-project",
  run_type: "chain",
  limit: 10
)
```

### Getting a Single Run

```ruby
run = client.get_run(run_id: "run-id")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
