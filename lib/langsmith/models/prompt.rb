module Langsmith
  module Models
    class Prompt < BaseModel
      attr_reader :template, :model, :tools

      # Pull a prompt with optional model information from the hub
      # @param repo_name [String] The prompt repository name
      # @param commit_hash [String, nil] A specific commit hash to pull
      # @param include_model [Boolean] Whether to include model information
      # @return [Prompt] A prompt object
      def self.pull(repo_name, commit_hash: nil, include_model: false)
        prompt_json = Langsmith.hub.pull(repo_name, commit_hash: commit_hash, include_model: include_model)
        from_json(prompt_json)
      end

      # Push this prompt to the LangSmith Hub
      # @param repo_name [String] The repository name to push to
      # @param is_public [Boolean, nil] Whether the prompt should be public
      # @param description [String, nil] A description of the prompt
      # @param readme [String, nil] A readme for the prompt
      # @param tags [Array<String>, nil] Tags for the prompt
      # @param parent_commit_hash [String] The parent commit hash
      # @return [String] The URL of the pushed prompt
      def push(repo_name, is_public: nil, description: nil, readme: nil, 
               tags: nil, parent_commit_hash: "latest")
        Langsmith.hub.push(
          repo_name,
          self,
          is_public: is_public,
          description: description,
          readme: readme,
          tags: tags,
          parent_commit_hash: parent_commit_hash
        )
      end

      def initialize(template:, model: nil, tools: [])
        @template = template
        @model = model
        @tools = tools.is_a?(Array) ? tools : []
      end

      def self.from_json(json)
        # Try first to parse as a chat prompt template
        template = ChatPromptTemplate.from_json(json)
        return unless template

        # Extract model if included in the JSON
        model_json = json.dig("config", "model")
        model = model_json ? Model.from_json(model_json) : nil
        
        # Extract tools from the prompt template or from a separate tools section
        tools = template.tools || []
        
        # If there are tools in a separate config section, use those instead
        tools_json = json.dig("config", "tools")
        if tools_json && tools_json.is_a?(Array) && !tools_json.empty?
          tools = tools_json.map { |tool_json| Tool.from_json(tool_json) }.compact
        end
        
        new(template: template, model: model, tools: tools)
      end

      def format(**kwargs)
        @template.format(**kwargs)
      end

      def to_json
        {
          template: @template.as_json,
          model: @model&.as_json,
          tools: @tools.map(&:as_json)
        }
      end
      
      def as_json
        to_json
      end

      # Check if this prompt has a model
      def has_model?
        !@model.nil?
      end
      
      # Get the model object if available
      def model
        @model
      end
      
      # Check if this prompt has tools
      def has_tools?
        !@tools.empty?
      end
      
      # Get all tools
      def tools
        @tools
      end
      
      # Get tool names
      def tool_names
        @tools.map(&:name)
      end
      
      # Find a specific tool by name
      def get_tool(name)
        @tools.find { |tool| tool.name == name }
      end
    end
  end
end