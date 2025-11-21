# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require_relative "middleware/authentication"

module PetstoreApiClient
  # Connection setup for HTTP requests
  # Tried HTTParty first but Faraday's middleware is cleaner for this use case
  module Connection
    private

    # Creates and memoizes a Faraday connection (reuses same connection for better performance)
    def connection
      @connection ||= Faraday.new(url: configuration.base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/

        # Add authentication middleware (Strategy pattern + Interceptor pattern)
        # This uses the authentication strategy from configuration
        conn.use Middleware::Authentication, authenticator: configuration.authenticator

        # Add retry middleware for transient failures (finally got around to implementing this!)
        setup_retry_middleware(conn) if configuration.retry_enabled

        # Standard headers for JSON API
        conn.headers["Content-Type"] = "application/json"
        conn.headers["Accept"] = "application/json"

        # Timeouts to prevent hanging requests
        conn.options.timeout = configuration.timeout
        conn.options.open_timeout = configuration.open_timeout

        conn.adapter Faraday.default_adapter
      end
    end

    # Configure retry middleware with sensible defaults
    def setup_retry_middleware(conn)
      conn.request :retry,
                   max: configuration.max_retries,
                   interval: 0.5,
                   interval_randomness: 0.5,
                   backoff_factor: 2,
                   retry_statuses: [429, 500, 502, 503, 504], # Retry on these HTTP codes
                   methods: %i[get post put delete], # Retry all methods
                   exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError]
    end

    # Reset connection when config changes
    def reset_connection!
      @connection = nil
    end
  end
end
