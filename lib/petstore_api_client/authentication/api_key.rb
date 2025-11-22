# frozen_string_literal: true

require_relative "base"

module PetstoreApiClient
  module Authentication
    # API Key authentication strategy
    # Adds api_key header to requests
    #
    # The Swagger Petstore API accepts api_key in the request header.
    # According to official docs, the special key is "special-key"
    #
    # Security best practices:
    # - API keys are validated before use
    # - Warnings issued for insecure (HTTP) connections
    # - Supports loading from environment variables
    #
    # @example Direct instantiation
    #   auth = ApiKey.new("special-key")
    #
    # @example From environment variable
    #   ENV['PETSTORE_API_KEY'] = "special-key"
    #   auth = ApiKey.from_env
    class ApiKey < Base
      # Header name for API key
      # According to Swagger Petstore spec: https://petstore.swagger.io
      HEADER_NAME = "api_key"

      # Environment variable name for API key
      ENV_VAR_NAME = "PETSTORE_API_KEY"

      # Minimum length for API key (security validation)
      MIN_KEY_LENGTH = 3

      attr_reader :api_key

      # Initialize API key authenticator
      #
      # @param api_key [String, nil] The API key to use
      # @raise [ValidationError] if API key is invalid
      # rubocop:disable Lint/MissingSuper
      def initialize(api_key = nil)
        @api_key = api_key&.to_s&.strip
        validate! if configured?
      end
      # rubocop:enable Lint/MissingSuper

      # Create authenticator from environment variable
      #
      # @return [ApiKey] New authenticator instance
      def self.from_env
        new(ENV.fetch(ENV_VAR_NAME, nil))
      end

      # Apply API key authentication to request
      # Adds api_key header to the request
      #
      # @param env [Faraday::Env] The request environment
      # @return [void]
      def apply(env)
        return unless configured?

        # Warn if sending API key over insecure connection (HTTP)
        warn_if_insecure!(env)

        # Add API key header
        env.request_headers[HEADER_NAME] = @api_key
      end

      # Check if API key is configured
      #
      # @return [Boolean]
      def configured?
        !@api_key.nil? && !@api_key.empty?
      end

      # String representation (masks API key for security)
      #
      # @return [String]
      def inspect
        return unconfigured_inspect unless configured?

        # Use base class method to mask credential (show first 4 chars)
        masked = mask_credential(@api_key, 4)

        "#<#{self.class.name} api_key=#{masked}>"
      end
      alias to_s inspect

      private

      # Validate API key format and length
      #
      # @raise [ValidationError] if API key is invalid
      def validate!
        return unless configured?

        # Use base class validation methods for DRY principle
        validate_credential_length(@api_key, "API key", MIN_KEY_LENGTH)
        validate_no_newlines(@api_key, "API key")
        validate_no_whitespace(@api_key, "API key")
      end

      # Note: warn_if_insecure! method inherited from Base class
    end
  end
end
