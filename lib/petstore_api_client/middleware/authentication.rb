# frozen_string_literal: true

module PetstoreApiClient
  module Middleware
    # Faraday middleware for authentication
    # Applies authentication strategy to each request
    #
    # This middleware follows the Interceptor pattern - it intercepts
    # outgoing requests and adds authentication headers before they're sent
    #
    # This is the same pattern used by industry-standard gems:
    # - Octokit (GitHub API)
    # - Slack-ruby-client
    # - Stripe Ruby
    #
    # @example
    #   # In Faraday connection setup
    #   conn.use PetstoreApiClient::Middleware::Authentication,
    #            authenticator: ApiKey.new("special-key")
    class Authentication < Faraday::Middleware
      # Initialize middleware with authentication strategy
      #
      # @param app [#call] The next middleware in the stack
      # @param options [Hash] Middleware options
      # @option options [Authentication::Base] :authenticator The auth strategy
      def initialize(app, options = {})
        super(app)
        @authenticator = options[:authenticator]
      end

      # Process request - apply authentication before sending
      #
      # @param env [Faraday::Env] The request environment
      # @return [Faraday::Response] The response from the next middleware
      def call(env)
        # Apply authentication if configured
        @authenticator&.apply(env) if @authenticator&.configured?

        # Continue to next middleware
        @app.call(env)
      end
    end
  end
end
