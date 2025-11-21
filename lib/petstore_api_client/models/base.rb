# frozen_string_literal: true

module PetstoreApiClient
  module Models
    # Base class for all API models
    # Provides common ActiveModel functionality and shared behavior
    #
    # This follows the DRY principle by centralizing all the common
    # ActiveModel includes that every model needs.
    #
    # Benefits:
    # - Single place to add model-wide functionality
    # - Consistent behavior across all models
    # - Reduces boilerplate in model classes
    class Base
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations
      include ActiveModel::Serialization

      # Convert model to hash for API requests
      # Subclasses can override this for custom serialization
      # Default implementation uses compact to remove nil values
      def to_h
        attributes.compact
      end

      # Create model instance from API response data
      # This is a template method - subclasses must implement their own
      # field mapping logic since each model has different fields
      #
      # @param data [Hash] Response data from API
      # @return [Base, nil] Model instance or nil if data is nil
      def self.from_response(data)
        raise NotImplementedError, "#{name} must implement .from_response"
      end

      class << self
        protected

        # Helper method to extract value from response data
        # Tries multiple key formats: camelCase, snake_case, symbol
        #
        # @param data [Hash] Response data
        # @param field [Symbol] Field name in snake_case
        # @param api_key [String, nil] Optional camelCase API key (if different from field)
        # @return [Object, nil] Field value or nil
        def extract_field(data, field, api_key = nil)
          return nil if data.nil?

          # Try API key (camelCase) first if provided
          value = data[api_key] if api_key
          # Then try snake_case string and symbol
          value ||= data[field.to_s] || data[field]
          value
        end
      end
    end
  end
end
