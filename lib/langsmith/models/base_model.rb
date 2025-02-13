module Langsmith
  module Models
    class BaseModel
      def self.from_json(json)
        new(**json.transform_keys(&:to_sym))
      end

      def to_json(*)
        to_h.to_json
      end

      def to_h
        instance_variables.each_with_object({}) do |var, hash|
          key = var.to_s.delete("@")
          value = instance_variable_get(var)
          hash[key] = value
        end
      end
    end
  end
end
