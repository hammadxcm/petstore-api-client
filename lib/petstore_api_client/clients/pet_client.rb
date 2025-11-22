# frozen_string_literal: true

require_relative "concerns/resource_operations"
require_relative "concerns/pagination"

module PetstoreApiClient
  module Clients
    # Client for Pet-related API endpoints
    # Handles creation, retrieval, updating, and deletion of pets
    #
    # Refactored to use ResourceOperations concern (Template Method pattern)
    # which eliminates ~50 lines of duplication with StoreClient
    class PetClient < Client
      include Concerns::ResourceOperations
      include Concerns::Pagination

      # Public API methods - delegate to generic resource operations
      alias create_pet create_resource
      alias update_pet update_resource
      alias get_pet get_resource
      alias delete_pet delete_resource

      # Find pets by status with optional pagination
      #
      # @param status [String, Array<String>] Status value(s) to filter by
      #   Valid values: "available", "pending", "sold"
      # @param options [Hash] Optional pagination and filter options
      # @option options [Integer] :page Page number (default: 1)
      # @option options [Integer] :per_page Items per page (default: 25)
      # @option options [Integer] :offset Alternative: offset for results
      # @option options [Integer] :limit Alternative: limit for results
      # @return [PaginatedCollection<Pet>] Paginated collection of pets
      #
      # @example
      #   # Get first page of available pets
      #   pets = client.pets.find_by_status("available")
      #
      #   # Get second page with custom page size
      #   pets = client.pets.find_by_status("available", page: 2, per_page: 50)
      #
      #   # Search multiple statuses
      #   pets = client.pets.find_by_status(["available", "pending"])
      def find_by_status(status, options = {})
        # Validate status values
        statuses = Array(status)
        validate_statuses!(statuses)

        # Make API request (returns all matching pets)
        params = { status: statuses.join(",") }
        resp = get("pet/findByStatus", params: params)

        # Parse response into Pet objects
        pets = Array(resp.body).map { |pet_data| Models::Pet.from_response(pet_data) }

        # Apply client-side pagination (API doesn't support server-side pagination)
        apply_client_side_pagination(pets, options)
      end

      # Find pets by tags with optional pagination
      #
      # @param tags [String, Array<String>] Tag value(s) to filter by
      # @param options [Hash] Optional pagination options
      # @option options [Integer] :page Page number (default: 1)
      # @option options [Integer] :per_page Items per page (default: 25)
      # @return [PaginatedCollection<Pet>] Paginated collection of pets
      #
      # @example
      #   # Find pets with specific tag
      #   pets = client.pets.find_by_tags("friendly")
      #
      #   # Find pets with multiple tags
      #   pets = client.pets.find_by_tags(["friendly", "vaccinated"], page: 1, per_page: 10)
      def find_by_tags(tags, options = {})
        # Ensure tags is an array
        tag_array = Array(tags)
        raise ValidationError, "Tags cannot be empty" if tag_array.empty?

        # Make API request
        params = { tags: tag_array.join(",") }
        resp = get("pet/findByTags", params: params)

        # Parse response into Pet objects
        pets = Array(resp.body).map { |pet_data| Models::Pet.from_response(pet_data) }

        # Apply client-side pagination
        apply_client_side_pagination(pets, options)
      end

      private

      # Template method implementation: Define the model class
      def model_class
        Models::Pet
      end

      # Template method implementation: Define the resource name for API paths
      def resource_name
        "pet"
      end

      # Template method implementation: Human-readable name for validation errors
      def id_field_name
        "Pet ID"
      end

      # Validate status values against allowed values
      def validate_statuses!(statuses)
        # Performance optimization: use constant instead of creating new array
        invalid = statuses.reject { |s| Models::Pet::VALID_STATUSES.include?(s.to_s) }

        return if invalid.empty?

        raise ValidationError,
              "Invalid status value(s): #{invalid.join(", ")}. " \
              "Must be one of: #{Models::Pet::VALID_STATUSES.join(", ")}"
      end
    end
  end
end
