# frozen_string_literal: true

require_relative "base"

module PetstoreApiClient
  module Authentication
    # No authentication strategy (Null Object pattern)
    # Used when no authentication is configured
    #
    # This allows the authentication system to always have an authenticator
    # without needing nil checks everywhere
    #
    # @example
    #   auth = None.new
    #   auth.configured? # => false
    #   auth.apply(env)  # Does nothing
    class None < Base
      # Apply no authentication (does nothing)
      #
      # @param _env [Faraday::Env] The request environment (unused)
      # @return [void]
      def apply(_env)
        # Intentionally empty - no authentication to apply
      end

      # Check if authentication is configured
      #
      # @return [Boolean] Always false
      def configured?
        false
      end

      # String representation
      #
      # @return [String]
      def inspect
        "#<#{self.class.name} (no authentication)>"
      end
      alias to_s inspect
    end
  end
end
