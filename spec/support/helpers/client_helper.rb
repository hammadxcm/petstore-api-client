# frozen_string_literal: true

module ClientHelper
  # Creates a basic configuration object for testing
  #
  # @param options [Hash] Optional configuration overrides
  # @return [PetstoreApiClient::Configuration] configured instance
  def build_config(**options)
    config = PetstoreApiClient::Configuration.new
    options.each do |key, value|
      config.public_send(:"#{key}=", value)
    end
    config
  end

  # Creates a client instance with optional configuration
  #
  # @param config [PetstoreApiClient::Configuration] Optional config (creates new if nil)
  # @param client_class [Class] The client class to instantiate (auto-detects from described_class if not provided)
  # @return [Object] Instance of the client class
  def build_client(config = nil, client_class: nil)
    config ||= build_config
    client_class ||= described_class
    client_class.new(config)
  end

  # Creates both config and client for convenience
  #
  # @param config_options [Hash] Optional configuration overrides
  # @return [Array<PetstoreApiClient::Configuration, Object>] config and client instances
  def setup_client(**config_options)
    config = build_config(**config_options)
    client = build_client(config)
    [config, client]
  end
end

# Include helper in all specs
RSpec.configure do |config|
  config.include ClientHelper
end
