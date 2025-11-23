# frozen_string_literal: true

require_relative "base"

module PetstoreApiClient
  module Authentication
    # Composite authentication strategy for applying multiple auth methods simultaneously
    #
    # This authenticator implements the Composite pattern, allowing multiple authentication
    # strategies to be applied to a single request. This is particularly useful during
    # migration periods when transitioning from one auth method to another, or when an
    # API accepts multiple authentication methods.
    #
    # The Petstore API accepts both API Key and OAuth2 authentication. Using this composite
    # authenticator, you can send both headers simultaneously, allowing the server to
    # accept either authentication method.
    #
    # All configured strategies are applied in the order they were added. Each strategy's
    # apply() method is called, allowing it to add its own headers to the request.
    #
    # @example Using both API Key and OAuth2
    #   api_key_auth = ApiKey.new("special-key")
    #   oauth2_auth = OAuth2.new(client_id: "id", client_secret: "secret")
    #   composite = Composite.new([api_key_auth, oauth2_auth])
    #
    #   composite.apply(env)
    #   # Request now has both:
    #   # - api_key: special-key
    #   # - Authorization: Bearer <token>
    #
    # @example Building from configuration
    #   strategies = []
    #   strategies << ApiKey.new(config.api_key) if config.api_key
    #   strategies << OAuth2.new(...) if config.oauth2_client_id
    #   composite = Composite.new(strategies)
    #
    # @see https://refactoring.guru/design-patterns/composite Composite Pattern
    # @since 0.2.0
    class Composite < Base
      # @!attribute [r] strategies
      #   @return [Array<Base>] List of authentication strategies to apply
      attr_reader :strategies

      # Initialize composite authenticator with multiple strategies
      #
      # @param strategies [Array<Base>] List of authentication strategies
      #   Each strategy must respond to #apply(env) and #configured?
      #
      # @raise [ArgumentError] if strategies is not an array
      # @raise [ArgumentError] if any strategy doesn't inherit from Base
      #
      # @example
      #   api_key = ApiKey.new("my-key")
      #   oauth2 = OAuth2.new(client_id: "id", client_secret: "secret")
      #   composite = Composite.new([api_key, oauth2])
      #
      # rubocop:disable Lint/MissingSuper
      def initialize(strategies = [])
        unless strategies.is_a?(Array)
          raise ArgumentError, "strategies must be an Array (got #{strategies.class})"
        end

        validate_strategies!(strategies)
        @strategies = strategies
        # Performance optimization: cache configured strategies to avoid repeated checks
        @configured_strategies = @strategies.select(&:configured?)
      end
      # rubocop:enable Lint/MissingSuper

      # Apply all configured authentication strategies to the request
      #
      # Iterates through all strategies and calls apply() on each one if it's configured.
      # This allows multiple authentication headers to be added to the same request.
      #
      # @param env [Faraday::Env] The Faraday request environment
      # @return [void]
      #
      # @example
      #   composite = Composite.new([api_key_auth, oauth2_auth])
      #   composite.apply(env)
      #   # Both authentication methods are now applied
      #
      def apply(env)
        # Performance optimization: use cached configured strategies
        # Avoids checking configured? on every request
        @configured_strategies.each { |strategy| strategy.apply(env) }
      end

      # Check if any authentication strategy is configured
      #
      # Returns true if at least one strategy in the composite is configured.
      # Returns false if no strategies are configured or if strategies array is empty.
      #
      # @return [Boolean] true if at least one strategy is configured
      #
      # @example
      #   # No strategies configured
      #   composite = Composite.new([])
      #   composite.configured? # => false
      #
      #   # One strategy configured
      #   api_key = ApiKey.new("my-key")
      #   composite = Composite.new([api_key])
      #   composite.configured? # => true
      #
      #   # Mixed (one configured, one not)
      #   oauth2 = OAuth2.new # Not configured (no credentials)
      #   composite = Composite.new([api_key, oauth2])
      #   composite.configured? # => true (at least one is configured)
      #
      def configured?
        # Performance optimization: use cached configured strategies
        !@configured_strategies.empty?
      end

      # Get list of configured strategy types
      #
      # Returns array of type names for strategies that are actually configured.
      # Useful for debugging and logging.
      #
      # @return [Array<String>] List of configured strategy type names
      #
      # @example
      #   api_key = ApiKey.new("key")
      #   oauth2 = OAuth2.new # Not configured
      #   composite = Composite.new([api_key, oauth2])
      #   composite.configured_types # => ["ApiKey"]
      #
      def configured_types
        @strategies.select(&:configured?).map(&:type)
      end

      # String representation showing all configured strategies
      #
      # @return [String] Human-readable representation
      #
      # @example
      #   composite = Composite.new([api_key, oauth2])
      #   composite.inspect
      #   # => "#<Composite strategies=[ApiKey, OAuth2] configured=[ApiKey, OAuth2]>"
      #
      def inspect
        all_types = @strategies.map(&:type).join(", ")
        configured = configured_types.join(", ")
        configured = "none" if configured.empty?

        "#<#{self.class.name} strategies=[#{all_types}] configured=[#{configured}]>"
      end
      alias to_s inspect

      private

      # Validate that all strategies are valid authentication strategy objects
      #
      # @param strategies [Array] List of strategies to validate
      # @return [void]
      # @raise [ArgumentError] if any strategy is invalid
      #
      def validate_strategies!(strategies)
        strategies.each_with_index do |strategy, index|
          unless strategy.is_a?(Base)
            raise ArgumentError,
                  "Strategy at index #{index} must inherit from Authentication::Base " \
                  "(got #{strategy.class})"
          end

          unless strategy.respond_to?(:apply)
            raise ArgumentError,
                  "Strategy at index #{index} (#{strategy.class}) must respond to #apply"
          end

          unless strategy.respond_to?(:configured?)
            raise ArgumentError,
                  "Strategy at index #{index} (#{strategy.class}) must respond to #configured?"
          end
        end
      end
    end
  end
end
