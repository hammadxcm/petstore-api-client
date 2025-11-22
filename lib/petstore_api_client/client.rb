# frozen_string_literal: true

module PetstoreApiClient
  # Base HTTP client for Petstore API
  #
  # Provides low-level HTTP communication with the Petstore API. This class
  # includes Connection and Request modules to handle connection management
  # and HTTP request execution.
  #
  # Most users should use the higher-level PetClient or StoreClient instead
  # of using this class directly.
  #
  # @example Creating a client with default configuration
  #   client = PetstoreApiClient::Client.new
  #
  # @example Creating a client with custom configuration
  #   config = PetstoreApiClient::Configuration.new
  #   config.api_key = "special-key"
  #   config.timeout = 60
  #   client = PetstoreApiClient::Client.new(config)
  #
  # @example Configuring an existing client
  #   client = PetstoreApiClient::Client.new
  #   client.configure do |c|
  #     c.api_key = "special-key"
  #     c.timeout = 60
  #   end
  #
  # @see Connection Connection management
  # @see Request HTTP request methods
  # @since 0.1.0
  class Client
    include Connection
    include Request

    # @!attribute [r] configuration
    #   @return [Configuration] The configuration object for this client
    attr_reader :configuration

    # Initialize a new HTTP client
    #
    # Creates a new client instance with the provided configuration.
    # If no configuration is provided, uses default configuration.
    # Validates configuration before creating the client.
    #
    # @param config [Configuration, nil] Optional configuration object.
    #   If nil, creates a new Configuration with defaults.
    #
    # @raise [ValidationError] if configuration is invalid
    #
    # @example With default configuration
    #   client = Client.new
    #
    # @example With custom configuration
    #   config = Configuration.new
    #   config.api_key = "special-key"
    #   client = Client.new(config)
    #
    def initialize(config = nil)
      @configuration = config || Configuration.new
      @configuration.validate!
    end

    # Configure the client via block
    #
    # Yields the configuration object to the block for modification.
    # Automatically resets the connection after configuration changes
    # to ensure new settings are applied.
    #
    # @yieldparam [Configuration] configuration The configuration object
    # @return [Client] self for method chaining
    #
    # @example
    #   client = Client.new
    #   client.configure do |config|
    #     config.api_key = "special-key"
    #     config.timeout = 60
    #     config.retry_enabled = false
    #   end
    #
    def configure
      yield(configuration) if block_given?
      reset_connection! # Need to reset when config changes
      self
    end
  end
end
