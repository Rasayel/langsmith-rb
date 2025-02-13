RSpec.describe Langsmith::Chat do
  let(:thread_id) { "123e4567-e89b-12d3-a456-426614174000" }
  let(:project_name) { "test_project" }
  let(:openai_client) { double }
  let(:chat) { described_class.new(thread_id: thread_id, project_name: project_name, llm: openai_client) }

  before do
    # Stub the hub pull request
    stub_request(:get, "#{Langsmith.configuration.api_url}/hub/pull/qualify-agent")
      .with(headers: { "x-api-key" => Langsmith.configuration.api_key })
      .to_return(
        status: 200,
        body: {
          template_type: "chat",
          input_variables: ["query"],
          messages: []
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe "#initialize" do
    it "initializes with default settings" do
      expect(chat.thread_id).to eq(thread_id)
      expect(chat.project_name).to eq(project_name)
    end

    it "generates a new UUID if thread_id is invalid" do
      expect {
        described_class.new(thread_id: "invalid", llm: openai_client)
      }.to raise_error(Langsmith::ValidationError, "Invalid thread ID format")
    end
  end

  describe "#get_chat_history" do
    it "retrieves chat history" do
      runs = [
        { id: "run_1", type: "llm", outputs: { response: "Hello" } },
        { id: "run_2", type: "llm", outputs: { response: "Hi there" } }
      ]
      
      stub_request(:post, "#{Langsmith.configuration.api_url}/api/v1/runs/query")
        .with(
          body: hash_including("project_name" => project_name),
          headers: { "x-api-key" => Langsmith.configuration.api_key }
        )
        .to_return(
          status: 200,
          body: { runs: runs }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      
      history = chat.get_chat_history
      expect(history).to be_an(Array)
      expect(history.length).to eq(2)
    end
  end

  describe "#complete" do
    let(:messages) { [{ role: "user", content: "Hello" }] }
    let(:completion_response) do
      {
        id: "response_123",
        choices: [
          {
            message: {
              role: "assistant",
              content: "Hello! How can I help you today?"
            }
          }
        ]
      }
    end

    before do
      # Stub run creation and update
      stub_request(:post, "#{Langsmith.configuration.api_url}/api/v1/runs")
        .with(headers: { "x-api-key" => Langsmith.configuration.api_key })
        .to_return(
          status: 200,
          body: { id: "run_123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:patch, "#{Langsmith.configuration.api_url}/api/v1/runs/run_123")
        .with(headers: { "x-api-key" => Langsmith.configuration.api_key })
        .to_return(
          status: 200,
          body: { id: "run_123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub OpenAI client response
      allow(openai_client).to receive(:chat).and_return(completion_response)
    end

    it "gets a completion from the LLM" do
      response = chat.complete(messages)
      expect(symbolize_hash(response)[:choices][0][:message][:content])
        .to eq("Hello! How can I help you today?")
    end

    it "handles API errors" do
      allow(openai_client).to receive(:chat).and_raise(Langsmith::APIError.new("API Error"))
      expect { chat.complete(messages) }.to raise_error(Langsmith::APIError)
    end
  end
end
