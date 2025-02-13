module Langsmith
  module Traceable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def traceable(name: nil, run_type: "chain", tags: [], metadata: {}, parent_run_id: nil)
        original_method = instance_method(:call)
        
        define_method(:call) do |*args, **kwargs|
          # Get parent run ID if it's a lambda
          parent_id = case parent_run_id
          when Proc
            parent_run_id.call(self, *args, **kwargs)
          else
            parent_run_id
          end

          # Get metadata if it's a lambda
          meta = metadata.respond_to?(:call) ? instance_exec(&metadata) : metadata

          # Create a run tree for this operation
          run = Langsmith::RunTree.new(
            name: name || self.class.name,
            run_type: run_type,
            inputs: {
              input: args.first,  # Single input for chat
              **kwargs           # Additional kwargs like messages
            },
            tags: tags,
            metadata: meta,
            parent_run_id: parent_id,
            session_id: meta["session_id"]
          )

          begin
            # Post the run first
            run.post

            # Call the original method
            result = original_method.bind(self).call(*args, **kwargs)

            # Update the run with success
            outputs = if result.is_a?(Hash)
              result  # Already a hash, use as is
            else
              { "output" => result }  # Wrap string/other types in a hash
            end
            run.end(outputs: outputs)
            run.patch

            result
          rescue StandardError => e
            # Update the run with error if we have a run ID
            if run.id
              run.end(error: e.message)
              run.patch
            end
            raise e
          end
        end
      end
    end
  end
end
