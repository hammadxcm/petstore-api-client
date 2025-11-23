# frozen_string_literal: true

require "oauth2"
require_relative "base"

module PetstoreApiClient
  module Authentication
    # OAuth2 authentication strategy for Petstore API
    #
    # Implements OAuth2 Client Credentials flow for server-to-server authentication.
    # Automatically handles token fetching, caching, and refresh on expiration.
    #
    # This implementation follows the same security best practices as the ApiKey strategy:
    # - HTTPS enforcement with warnings for insecure connections
    # - Token masking in logs and debug output
    # - Environment variable support for secure credential storage
    # - Thread-safe token management
    #
    # @example Basic usage with explicit credentials
    #   auth = OAuth2.new(
    #     client_id: "my-client-id",
    #     client_secret: "my-secret",
    #     token_url: "https://petstore.swagger.io/oauth/token"
    #   )
    #   auth.configured? # => true
    #
    # @example Loading from environment variables
    #   ENV['PETSTORE_OAUTH2_CLIENT_ID'] = 'my-client-id'
    #   ENV['PETSTORE_OAUTH2_CLIENT_SECRET'] = 'my-secret'
    #   ENV['PETSTORE_OAUTH2_TOKEN_URL'] = 'https://petstore.swagger.io/oauth/token'
    #   auth = OAuth2.from_env
    #
    # @example With custom scope
    #   auth = OAuth2.new(
    #     client_id: "my-client-id",
    #     client_secret: "my-secret",
    #     token_url: "https://petstore.swagger.io/oauth/token",
    #     scope: "read:pets write:pets"
    #   )
    #
    # @see https://oauth.net/2/ OAuth 2.0 Specification
    # @see https://tools.ietf.org/html/rfc6749#section-4.4 Client Credentials Grant
    # @since 0.2.0
    class OAuth2 < Base
      # Default token URL for Petstore API
      DEFAULT_TOKEN_URL = "https://petstore.swagger.io/oauth/token"

      # Default OAuth2 scope for Petstore API (supports both read and write)
      DEFAULT_SCOPE = "read:pets write:pets"

      # Environment variable names for OAuth2 credentials
      ENV_CLIENT_ID = "PETSTORE_OAUTH2_CLIENT_ID"
      ENV_CLIENT_SECRET = "PETSTORE_OAUTH2_CLIENT_SECRET"
      ENV_TOKEN_URL = "PETSTORE_OAUTH2_TOKEN_URL"
      ENV_SCOPE = "PETSTORE_OAUTH2_SCOPE"

      # Minimum seconds before expiration to trigger token refresh
      # If token expires in less than this time, fetch a new one
      TOKEN_REFRESH_BUFFER = 60

      # Minimum length requirements for credentials (security validation)
      MIN_ID_LENGTH = 3
      MIN_SECRET_LENGTH = 3

      # @!attribute [r] client_id
      #   @return [String, nil] OAuth2 client ID
      attr_reader :client_id

      # @!attribute [r] client_secret
      #   @return [String, nil] OAuth2 client secret (masked in output)
      attr_reader :client_secret

      # @!attribute [r] token_url
      #   @return [String] OAuth2 token endpoint URL
      attr_reader :token_url

      # @!attribute [r] scope
      #   @return [String, nil] OAuth2 scope (space-separated permissions)
      attr_reader :scope

      # Initialize OAuth2 authenticator with client credentials
      #
      # @param client_id [String, nil] OAuth2 client ID
      # @param client_secret [String, nil] OAuth2 client secret
      # @param token_url [String] OAuth2 token endpoint URL
      # @param scope [String, nil] OAuth2 scope (space-separated permissions)
      #
      # @raise [ValidationError] if credentials are invalid format
      #
      # @example
      #   auth = OAuth2.new(
      #     client_id: "my-app",
      #     client_secret: "secret123",
      #     token_url: "https://api.example.com/oauth/token",
      #     scope: "read write"
      #   )
      #
      # rubocop:disable Lint/MissingSuper
      def initialize(client_id: nil, client_secret: nil, token_url: DEFAULT_TOKEN_URL, scope: nil)
        @client_id = client_id&.to_s&.strip
        @client_secret = client_secret&.to_s&.strip
        @token_url = token_url || DEFAULT_TOKEN_URL
        @scope = scope&.to_s&.strip
        @access_token = nil
        @token_mutex = Mutex.new # Thread-safe token access

        validate! if configured?
      end
      # rubocop:enable Lint/MissingSuper

      # Create OAuth2 authenticator from environment variables
      #
      # Loads credentials from:
      # - PETSTORE_OAUTH2_CLIENT_ID
      # - PETSTORE_OAUTH2_CLIENT_SECRET
      # - PETSTORE_OAUTH2_TOKEN_URL (optional, defaults to Petstore API)
      # - PETSTORE_OAUTH2_SCOPE (optional)
      #
      # @return [OAuth2] New authenticator instance
      #
      # @example
      #   ENV['PETSTORE_OAUTH2_CLIENT_ID'] = 'my-id'
      #   ENV['PETSTORE_OAUTH2_CLIENT_SECRET'] = 'my-secret'
      #   auth = OAuth2.from_env
      #   auth.configured? # => true
      #
      def self.from_env
        new(
          client_id: ENV.fetch(ENV_CLIENT_ID, nil),
          client_secret: ENV.fetch(ENV_CLIENT_SECRET, nil),
          token_url: ENV.fetch(ENV_TOKEN_URL, DEFAULT_TOKEN_URL),
          scope: ENV.fetch(ENV_SCOPE, nil)
        )
      end

      # Apply OAuth2 authentication to Faraday request
      #
      # Adds Authorization header with Bearer token.
      # Automatically fetches or refreshes token if needed.
      #
      # @param env [Faraday::Env] The Faraday request environment
      # @return [void]
      #
      # @raise [AuthenticationError] if token fetch fails
      #
      # @example
      #   auth = OAuth2.new(client_id: "id", client_secret: "secret")
      #   auth.apply(faraday_env)
      #   # Request now has: Authorization: Bearer <access_token>
      #
      def apply(env)
        return unless configured?

        # Warn if sending credentials over insecure connection
        warn_if_insecure!(env)

        # Ensure we have a valid token
        ensure_valid_token!

        # Add Authorization header with Bearer token
        env.request_headers["Authorization"] = "Bearer #{@access_token.token}"
      end

      # Check if OAuth2 credentials are configured
      #
      # @return [Boolean] true if client_id and client_secret are present
      #
      # @example
      #   auth = OAuth2.new(client_id: "id", client_secret: "secret")
      #   auth.configured? # => true
      #
      #   auth = OAuth2.new
      #   auth.configured? # => false
      #
      def configured?
        !@client_id.nil? && !@client_id.empty? &&
          !@client_secret.nil? && !@client_secret.empty?
      end

      # Fetch a new access token from OAuth2 server
      #
      # Uses Client Credentials flow to obtain an access token.
      # Token is cached and reused until expiration.
      #
      # @return [OAuth2::AccessToken] The access token object
      #
      # @raise [AuthenticationError] if token fetch fails
      #
      # @example
      #   auth = OAuth2.new(client_id: "id", client_secret: "secret")
      #   token = auth.fetch_token!
      #   token.token # => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
      #
      def fetch_token!
        @token_mutex.synchronize do
          client = build_oauth2_client
          @access_token = client.client_credentials.get_token(scope: @scope)
        rescue ::OAuth2::Error => e
          raise AuthenticationError,
                "OAuth2 token fetch failed: #{e.message}"
        end
      end

      # Check if current access token is expired or will expire soon
      #
      # Returns true if token is nil, already expired, or expires within
      # TOKEN_REFRESH_BUFFER seconds.
      #
      # @return [Boolean] true if token needs refresh
      #
      # @example
      #   auth.token_expired? # => true (no token yet)
      #   auth.fetch_token!
      #   auth.token_expired? # => false (fresh token)
      #
      def token_expired?
        return true if @access_token.nil?
        return true if @access_token.expired?

        # Refresh if expiring soon (within buffer window)
        return false if @access_token.expires_at.nil?

        Time.now.to_i >= (@access_token.expires_at - TOKEN_REFRESH_BUFFER)
      end

      # String representation (masks client secret for security)
      #
      # @return [String] Masked representation of OAuth2 config
      #
      # @example
      #   auth = OAuth2.new(client_id: "my-app", client_secret: "secret123")
      #   auth.inspect # => "#<OAuth2 client_id=my-app secret=sec*******>"
      #
      def inspect
        return unconfigured_inspect unless configured?

        # Use base class method to mask credentials
        masked_secret = mask_credential(@client_secret, 3)

        token_status = if @access_token.nil?
                         "no token"
                       elsif token_expired?
                         "token expired"
                       else
                         "token valid"
                       end

        "#<#{self.class.name} client_id=#{@client_id} secret=#{masked_secret} (#{token_status})>"
      end
      alias to_s inspect

      private

      # Validate OAuth2 credentials format
      #
      # @return [void]
      # @raise [ValidationError] if credentials are invalid
      #
      def validate!
        return unless configured?

        # Use base class validation methods for DRY principle
        validate_credential_length(@client_id, "OAuth2 client_id", MIN_ID_LENGTH)
        validate_credential_length(@client_secret, "OAuth2 client_secret", MIN_SECRET_LENGTH)
        validate_no_newlines(@client_id, "OAuth2 client_id")
        validate_no_newlines(@client_secret, "OAuth2 client_secret")
      end

      # Build OAuth2 client for token operations
      #
      # @return [::OAuth2::Client] OAuth2 client instance
      #
      def build_oauth2_client
        ::OAuth2::Client.new(
          @client_id,
          @client_secret,
          site: token_site,
          token_url: @token_url
        )
      end

      # Extract site URL from token_url
      # OAuth2 gem requires separate site and token_url
      #
      # @return [String] Base site URL
      #
      def token_site
        uri = URI.parse(@token_url)
        "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && uri.port != 80 && uri.port != 443}"
      end

      # Ensure we have a valid access token
      # Fetches new token if needed
      #
      # @return [void]
      # @raise [AuthenticationError] if token fetch fails
      #
      def ensure_valid_token!
        fetch_token! if token_expired?
      end

      # Note: warn_if_insecure! method inherited from Base class
    end
  end
end
