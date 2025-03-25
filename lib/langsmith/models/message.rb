module Langsmith
  module Models
    class Message < BaseModel
      attr_reader :content, :additional_kwargs, :response_metadata

      def initialize(content:, additional_kwargs: {}, response_metadata: {})
        @content = content
        @additional_kwargs = additional_kwargs || {}
        @response_metadata = response_metadata || {}
      end

      def self.from_json(json)
        # Debug output if DEBUG is enabled
        if ENV["DEBUG"]
          puts "DEBUG Message.from_json: Processing message with ID: #{json['id'].join(', ') if json['id']}"
          puts "DEBUG Message.from_json: Type: #{json['type']}"
          puts "DEBUG Message.from_json: Content: #{json.dig('kwargs', 'content')&.slice(0, 50)}..."
        end
        
        return unless json["type"] == "constructor" &&
                    json["id"].first(2) == ["langchain_core", "messages"]

        # Extract the message type from the ID
        message_type = json["id"].last

        # Create the appropriate message subclass based on type
        case message_type
        when "SystemMessage"
          puts "DEBUG: Creating SystemMessage" if ENV["DEBUG"]
          SystemMessage.new(**json["kwargs"].transform_keys(&:to_sym))
        when "HumanMessage"
          puts "DEBUG: Creating HumanMessage" if ENV["DEBUG"]
          HumanMessage.new(**json["kwargs"].transform_keys(&:to_sym))
        when "AIMessage"
          puts "DEBUG: Creating AIMessage" if ENV["DEBUG"]
          AIMessage.new(**json["kwargs"].transform_keys(&:to_sym))
        when "ToolMessage"
          puts "DEBUG: Creating ToolMessage" if ENV["DEBUG"]
          ToolMessage.new(**json["kwargs"].transform_keys(&:to_sym))
        else
          puts "DEBUG: Unrecognized message type: #{message_type}" if ENV["DEBUG"]
          # Default to base Message class for unrecognized types
          new(**json["kwargs"].transform_keys(&:to_sym))
        end
      end

      def role
        raise NotImplementedError, "Subclasses must implement role"
      end

      def as_json
        {
          content: @content,
          additional_kwargs: @additional_kwargs,
          response_metadata: @response_metadata
        }
      end
    end

    class SystemMessage < Message
      def role
        "system"
      end
    end

    class HumanMessage < Message
      def role
        "user"
      end
    end

    class AIMessage < Message
      def role
        "assistant" 
      end
    end

    class ToolMessage < Message
      attr_reader :tool_call_id, :name

      def initialize(content:, additional_kwargs: {}, response_metadata: {}, tool_call_id: nil, name: nil)
        super(content: content, additional_kwargs: additional_kwargs, response_metadata: response_metadata)
        @tool_call_id = tool_call_id
        @name = name
      end

      def role
        "tool"
      end

      def as_json
        super.merge(tool_call_id: @tool_call_id, name: @name)
      end
    end
  end
end
