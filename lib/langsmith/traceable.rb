module Langsmith
  module Traceable
    # Includes this module to enable tracing on methods
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods to extend onto including class
    module ClassMethods
      # Adds tracing to a method with optional parameters
      # 
      # @param method_name [Symbol] Name of the method to trace
      # @param name [String, Proc] Name of the run trace, defaults to method name
      # @param run_type [String] Type of run, defaults to "chain"
      # @param tags [Array<String>] Tags to add to the run
      # @param metadata [Hash, Proc] Metadata to add to the run
      # @param parent_run_id [String, Proc] Parent run ID to link to
      def traceable(method_name, name: nil, run_type: "chain", tags: [], metadata: {}, parent_run_id: nil)
        # Store the original method
        original_method = instance_method(method_name)

        # Define a new method with the same name that wraps the original
        define_method(method_name) do |*args, **kwargs|
          # Get the name, either from the parameter or the method name
          run_name = if name.respond_to?(:call)
            name.call(*args, **kwargs)
          else
            name || method_name.to_s
          end
          
          # Get parent run ID from parameter or current run tree
          parent_id = if parent_run_id.respond_to?(:call)
              parent_run_id.call(self, *args, **kwargs)
            else
              parent_run_id || Langsmith.current_run_tree&.id
            end

          # Get metadata based on type
          meta = case metadata
          when Proc
            begin
              metadata.call(self, *args, **kwargs)
            rescue ArgumentError
              # If the proc has wrong arity, call without args
              begin
                metadata.call
              rescue ArgumentError
                # If that also fails, just use an empty hash
                {}
              end
            end
          else
            metadata
          end

          # Prepare inputs
          inputs = {
            **kwargs  # Use kwargs as main inputs
          }
          
          # Add positional args if present
          inputs[:args] = args if args.any?

          # Use the Langsmith.trace method for consistency
          Langsmith.trace(
            name: run_name,
            run_type: run_type,
            inputs: inputs,
            tags: tags,
            metadata: meta,
            parent_run_id: parent_id
          ) do |run|
            # Call the original method
            result = original_method.bind(self).call(*args, **kwargs)
            
            # Return the result - trace will handle ending the run
            result
          end
        end
      end
    end

    # Helper method to create a trace easily
    # 
    # @param name [String] Name of the run
    # @param run_type [String] Type of run, defaults to "chain"
    # @param inputs [Hash] Inputs to the run
    # @param tags [Array<String>] Tags to add to the run
    # @param metadata [Hash] Metadata to add to the run
    # @param parent_run_id [String] Parent run ID to link to
    # @yield [run] Yields the run object to the block
    # @return [Object] Result of the block
    def trace(name:, run_type: "chain", inputs: {}, tags: [], metadata: {}, parent_run_id: nil, &block)
      # Use Langsmith.trace for consistency
      Langsmith.trace(
        name: name,
        run_type: run_type,
        inputs: inputs,
        tags: tags,
        metadata: metadata,
        parent_run_id: parent_run_id || Langsmith.current_run_tree&.id,
        &block
      )
    end
  end
end
