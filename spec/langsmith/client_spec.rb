RSpec.describe Langsmith::Client do
  let(:api_key) { "test_api_key" }
  let(:api_url) { "https://api.smith.langchain.com" }
  let(:client) { described_class.new(api_key: api_key, api_url: api_url) }

  describe "#initialize" do
    it "initializes with an API key and URL" do
      expect(client.api_key).to eq(api_key)
      expect(client.api_url).to eq(api_url)
    end

    it "raises error without API key" do
      expect { 
        described_class.new(api_url: api_url, api_key: nil) 
      }.to raise_error(Langsmith::ConfigurationError, "API key is required")
    end

    it "uses environment variable if no API key provided" do
      ENV["LANGCHAIN_API_KEY"] = "env_api_key"
      client = described_class.new(api_url: api_url, api_key: ENV["LANGCHAIN_API_KEY"])
      expect(client.api_key).to eq("env_api_key")
      ENV.delete("LANGCHAIN_API_KEY")
    end
  end

  describe "#create_run" do
    let(:run_params) do
      {
        name: "test_run",
        run_type: "chain",
        inputs: { test: "input" }
      }
    end

    it "creates a new run" do
      response_body = { id: "run_123", name: "test_run" }
      stub_request(:post, "#{api_url}/api/v1/runs")
        .with(
          body: hash_including(run_params.transform_keys(&:to_s)),
          headers: { "x-api-key" => api_key }
        )
        .to_return(
          status: 200,
          body: response_body.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = client.create_run(**run_params)
      expect(symbolize_hash(response)).to include(response_body)
    end
  end

  describe "#update_run" do
    let(:run_id) { "run_123" }
    let(:update_params) do
      {
        run_id: run_id,
        outputs: { result: "success" },
        end_time: Time.now.iso8601
      }
    end

    it "updates an existing run" do
      response_body = { id: run_id, outputs: update_params[:outputs] }
      stub_request(:patch, "#{api_url}/api/v1/runs/#{run_id}")
        .with(
          body: hash_including(outputs: update_params[:outputs].transform_keys(&:to_s)),
          headers: { "x-api-key" => api_key }
        )
        .to_return(
          status: 200,
          body: response_body.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = client.update_run(**update_params)
      expect(symbolize_hash(response)).to include(response_body)
    end
  end

  describe "#list_runs" do
    it "lists runs with filters" do
      runs = [{ id: "run_1" }, { id: "run_2" }]
      stub_request(:post, "#{api_url}/api/v1/runs/query")
        .with(
          body: hash_including("project_name" => "test_project"),
          headers: { "x-api-key" => api_key }
        )
        .to_return(
          status: 200,
          body: { runs: runs }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = client.list_runs(project_name: "test_project")
      expect(symbolize_hash(response)[:runs]).to eq(runs)
    end
  end
end
