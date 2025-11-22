# frozen_string_literal: true

module PetstoreApiClient
  module Clients
    module Concerns
      # Shared resource operations using Template Method pattern
      # Eliminates duplication between PetClient and StoreClient
      #
      # This module provides generic CRUD operations that work for any resource type.
      # Subclasses just need to define:
      # - model_class: The model class (e.g., Models::Pet)
      # - resource_name: The API path segment (e.g., "pet", "store/order")
      # - id_field_name: Human-readable name for validation errors (e.g., "Pet ID")
      module ResourceOperations
        # Template method for creating a resource
        # Pattern: build → validate → POST → parse response
        def create_resource(resource_data)
          resource = build_resource(resource_data)
          validate_resource!(resource)

          resp = post(create_endpoint, body: resource.to_h)
          model_class.from_response(resp.body)
        end

        # Template method for updating a resource
        # Pattern: build → validate → PUT → parse response
        def update_resource(resource_data)
          resource = build_resource(resource_data)
          validate_resource!(resource)

          resp = put(update_endpoint, body: resource.to_h)
          model_class.from_response(resp.body)
        end

        # Template method for getting a resource by ID
        # Pattern: validate ID → GET → parse response
        def get_resource(resource_id)
          validate_id!(resource_id, id_field_name)

          resp = get("#{resource_name}/#{resource_id}")
          model_class.from_response(resp.body)
        end

        # Template method for deleting a resource
        # Pattern: validate ID → DELETE → return success
        def delete_resource(resource_id)
          validate_id!(resource_id, id_field_name)

          delete("#{resource_name}/#{resource_id}")
          true
        end

        private

        # Build a resource object from various input types
        # Accepts either a model instance or hash of attributes
        def build_resource(resource_data)
          return resource_data if resource_data.is_a?(model_class)

          model_class.new(resource_data)
        end

        # Validate resource data before sending to API
        # Raises ValidationError if the model has validation errors
        def validate_resource!(resource)
          return if resource.valid?

          raise ValidationError, "Invalid #{resource_type_name} data: #{resource.errors.full_messages.join(", ")}"
        end

        # Validate that an ID is present and numeric
        # Accepts integers or numeric strings like "123"
        def validate_id!(id, field_name = "ID")
          raise ValidationError, "#{field_name} can't be nil" if id.nil?

          # String IDs are fine as long as they're numeric
          return if id.is_a?(Integer) || id.to_s.match?(/^\d+$/)

          raise ValidationError, "#{field_name} must be an integer, got #{id.class}"
        end

        # Abstract method: Subclasses must define the model class
        # Example: Models::Pet or Models::Order
        def model_class
          raise NotImplementedError, "#{self.class} must implement #model_class"
        end

        # Abstract method: Subclasses must define the resource name
        # Example: "pet" or "store/order"
        def resource_name
          raise NotImplementedError, "#{self.class} must implement #resource_name"
        end

        # Abstract method: Subclasses must define the endpoint for creating
        # Default implementation uses resource_name, but can be overridden
        def create_endpoint
          resource_name
        end

        # Abstract method: Subclasses must define the endpoint for updating
        # Default implementation uses resource_name, but can be overridden
        def update_endpoint
          resource_name
        end

        # Human-readable field name for ID validation errors
        # Default implementation capitalizes the resource name
        # Can be overridden for custom formatting
        def id_field_name
          "#{resource_type_name} ID"
        end

        # Extract resource type name from model class for error messages
        # Example: Models::Pet → "pet", Models::Order → "order"
        def resource_type_name
          model_class.name.split("::").last.downcase
        end
      end
    end
  end
end
