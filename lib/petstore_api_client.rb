# frozen_string_literal: true

require "active_model"
require "active_support/all"

require_relative "petstore_api_client/version"
require_relative "petstore_api_client/errors"
require_relative "petstore_api_client/configuration"
require_relative "petstore_api_client/response"
require_relative "petstore_api_client/paginated_collection"
require_relative "petstore_api_client/connection"
require_relative "petstore_api_client/request"
require_relative "petstore_api_client/client"

# Load validators
require_relative "petstore_api_client/validators/array_presence_validator"
require_relative "petstore_api_client/validators/enum_validator"

# Load models
require_relative "petstore_api_client/models/category"
require_relative "petstore_api_client/models/tag"
require_relative "petstore_api_client/models/api_response"
require_relative "petstore_api_client/models/pet"
require_relative "petstore_api_client/models/order"

# Load clients
require_relative "petstore_api_client/clients/pet_client"
require_relative "petstore_api_client/clients/store_client"
require_relative "petstore_api_client/api_client"

# Module for the Petstore API Client library
module PetstoreApiClient
  class << self
    attr_writer :configuration

    # Global configuration accessor
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the library globally
    # Example:
    #   PetstoreApiClient.configure do |config|
    #     config.api_key = "special-key"
    #   end
    def configure
      yield(configuration) if block_given?
    end

    # Reset the global configuration
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
