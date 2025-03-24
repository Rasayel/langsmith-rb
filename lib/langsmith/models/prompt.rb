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
        # First, normalize the structure - extract appropriate parts based on the JSON type
        template_json = extract_template_json(json)
        return unless template_json

        # Route to the appropriate prompt type based on the JSON ID
        case template_json["id"]
        when ["langchain", "prompts", "chat", "ChatPromptTemplate"]
          template = ChatPromptTemplate.from_json(template_json)
        when ["langchain_core", "prompts", "structured", "StructuredPrompt"]
          template = StructuredPrompt.from_json(template_json)
        else
          raise "Unknown prompt type"
        end

        # Extract model information
        model = extract_model_json(json)
        
        # Extract tools
        tools = extract_tools(json, template.tools)
        
        new(template: template, model: model, tools: tools)
      end

      # Extracts the template JSON from various formats
      # @param json [Hash] Original JSON from the API
      # @return [Hash, nil] Normalized template JSON or nil if not found
      def self.extract_template_json(json)
        if json["type"] == "constructor" && json["id"] == ["langchain", "schema", "runnable", "RunnableSequence"]
          # For RunnableSequence, the template is in the "first" section
          return json.dig("kwargs", "first")
        elsif json["type"] == "constructor" && json["id"] == ["langchain", "prompts", "chat", "ChatPromptTemplate"]
          # Direct ChatPromptTemplate
          return json
        end
        nil
      end

      # Extracts the model JSON from various formats
      # @param json [Hash] Original JSON from the API
      # @return [Model, nil] Parsed Model object or nil if not found
      def self.extract_model_json(json)
        model_json = nil
        
        if json["type"] == "constructor" && json["id"] == ["langchain", "schema", "runnable", "RunnableSequence"]
          # The model information is usually in the "last" -> "bound" section for RunnableSequence
          model_json = json.dig("kwargs", "last", "kwargs", "bound")
        else
          # Fall back to the old way of extracting model
          model_json = json.dig("config", "model")
        end
        
        Model.from_json(model_json) if model_json
      end

      # Extracts tools from various formats
      # @param json [Hash] Original JSON from the API
      # @param default_tools [Array] Default tools from the template
      # @return [Array<Tool>] Array of parsed Tool objects
      def self.extract_tools(json, default_tools = [])
        tools = default_tools || []
        
        if json["type"] == "constructor" && json["id"] == ["langchain", "schema", "runnable", "RunnableSequence"]
          # Check in the RunnableSequence format
          tools_json = json.dig("kwargs", "last", "kwargs", "tools")
          if tools_json && tools_json.is_a?(Array) && !tools_json.empty?
            tools = tools_json.map { |tool_json| Tool.from_json(tool_json) }.compact
          end
        else
          # Check in the older format
          tools_json = json.dig("config", "tools")
          if tools_json && tools_json.is_a?(Array) && !tools_json.empty?
            tools = tools_json.map { |tool_json| Tool.from_json(tool_json) }.compact
          end
        end
        
        tools
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