# frozen_string_literal: true

require_relative "concerns/resource_operations"

module PetstoreApiClient
  module Clients
    # Store client - handles order operations
    #
    # Refactored to use ResourceOperations concern (Template Method pattern)
    # which eliminates ~40 lines of duplication with PetClient
    class StoreClient < Client
      include Concerns::ResourceOperations

      # Public API methods - delegate to generic resource operations
      alias create_order create_resource
      alias get_order get_resource
      alias delete_order delete_resource

      private

      # Template method implementation: Define the model class
      def model_class
        Models::Order
      end

      # Template method implementation: Define the resource name for API paths
      def resource_name
        "store/order"
      end

      # Template method implementation: Human-readable name for validation errors
      def id_field_name
        "Order ID"
      end
    end
  end
end
