RSpec.describe Langsmith::Chain do
  let(:prompt_name) { "test_prompt" }
  let(:openai_client) { double }
  let(:chain) { described_class.new(prompt_name: prompt_name, llm: openai_client) }

  before do
    # Stub the hub pull request for the prompt template
    stub_request(:get, "#{Langsmith.configuration.api_url}/hub/pull/#{prompt_name}")
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
    it "initializes with a prompt name" do
      expect(chain.prompt_name).to eq(prompt_name)
    end

    it "uses default OpenAI LLM if none provided" do
      allow(OpenAI::Client).to receive(:new).and_return(openai_client)
      default_chain = described_class.new(prompt_name: prompt_name)
      expect(default_chain.llm).to be_a(Langsmith::Wrappers::OpenAI)
    end
  end

  describe "#call" do
    let(:inputs) { { query: "Test query" } }
    let(:run_id) { "run_123" }
    let(:completion_response) do
      {
        id: "response_123",
        choices: [
          {
            message: {
              role: "assistant",
              content: "Test response"
            }
          }
        ]
      }
    end

    before do
      # Stub run creation
      stub_request(:post, "#{Langsmith.configuration.api_url}/api/v1/runs")
        .with(headers: { "x-api-key" => Langsmith.configuration.api_key })
        .to_return(
          status: 200,
          body: { id: run_id }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      
      # Stub run update
      stub_request(:patch, "#{Langsmith.configuration.api_url}/api/v1/runs/#{run_id}")
        .with(headers: { "x-api-key" => Langsmith.configuration.api_key })
        .to_return(
          status: 200,
          body: { id: run_id }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub OpenAI client response
      allow(openai_client).to receive(:chat).and_return(completion_response)
    end

    it "executes the chain with given inputs" do
      response = chain.call(**inputs)
      expect(symbolize_hash(response)[:choices][0][:message][:content])
        .to eq("Test response")
    end

    it "handles errors in the chain" do
      allow(openai_client).to receive(:chat).and_raise(Langsmith::APIError.new("API Error"))
      expect { chain.call(**inputs) }.to raise_error(Langsmith::APIError)
    end
  end
end
