# frozen_string_literal: true

require_relative "authentication/api_key"
require_relative "authentication/oauth2"
require_relative "authentication/composite"
require_relative "authentication/none"

module PetstoreApiClient
  # Configuration management for Petstore API client
  #
  # Centralized configuration for all client settings including authentication,
  # timeouts, retries, and pagination. Supports multiple authentication strategies
  # via feature flags.
  #
  # @example Basic configuration
  #   config = Configuration.new
  #   config.api_key = "special-key"
  #   config.timeout = 60
  #
  # @example Block-based configuration
  #   config = Configuration.new
  #   config.configure do |c|
  #     c.auth_strategy = :oauth2
  #     c.oauth2_client_id = "my-id"
  #     c.oauth2_client_secret = "my-secret"
  #   end
  #
  # @since 0.1.0
  class Configuration
    # Default API base URL for Petstore API
    DEFAULT_BASE_URL = "https://petstore.swagger.io/v2"

    # Default number of items per page for paginated endpoints
    DEFAULT_PAGE_SIZE = 25

    # Maximum allowed page size to prevent abuse
    MAX_PAGE_SIZE = 100

    # Valid authentication strategy options
    VALID_AUTH_STRATEGIES = %i[none api_key oauth2 both].freeze

    # @!attribute [rw] base_url
    #   @return [String] Base URL for API endpoints
    # @!attribute [rw] timeout
    #   @return [Integer] Request timeout in seconds
    # @!attribute [rw] open_timeout
    #   @return [Integer] Connection open timeout in seconds
    # @!attribute [rw] retry_enabled
    #   @return [Boolean] Enable automatic retry for transient failures
    # @!attribute [rw] max_retries
    #   @return [Integer] Maximum number of retry attempts
    # @!attribute [rw] default_page_size
    #   @return [Integer] Default items per page for pagination
    # @!attribute [rw] max_page_size
    #   @return [Integer] Maximum items per page for pagination
    attr_accessor :base_url, :timeout, :open_timeout, :retry_enabled, :max_retries,
                  :default_page_size, :max_page_size

    # @!attribute [r] api_key
    #   @return [String, nil] API key for authentication (read-only, use setter)
    attr_reader :api_key

    # @!attribute [rw] auth_strategy
    #   @return [Symbol] Authentication strategy (:none, :api_key, :oauth2, :both)
    attr_accessor :auth_strategy

    # @!attribute [rw] oauth2_client_id
    #   @return [String, nil] OAuth2 client ID
    # @!attribute [rw] oauth2_client_secret
    #   @return [String, nil] OAuth2 client secret
    # @!attribute [rw] oauth2_token_url
    #   @return [String, nil] OAuth2 token endpoint URL
    # @!attribute [rw] oauth2_scope
    #   @return [String, nil] OAuth2 scope (space-separated permissions)
    attr_accessor :oauth2_client_id, :oauth2_client_secret, :oauth2_token_url, :oauth2_scope

    # Initialize configuration with default values
    #
    # Sets sensible defaults for all configuration options:
    # - base_url: Petstore API endpoint
    # - timeout: 30 seconds
    # - retry_enabled: true
    # - auth_strategy: :api_key (backward compatible)
    #
    # @example
    #   config = Configuration.new
    #   config.base_url # => "https://petstore.swagger.io/v2"
    #   config.timeout # => 30
    #
    def initialize
      @base_url = DEFAULT_BASE_URL
      @api_key = nil
      @timeout = 30 # seconds
      @open_timeout = 10 # seconds
      @retry_enabled = true # Auto-retry transient failures
      @max_retries = 2 # Number of retries for failed requests
      @default_page_size = DEFAULT_PAGE_SIZE # Default items per page for pagination
      @max_page_size = MAX_PAGE_SIZE # Maximum items per page (prevents abuse)
      @auth_strategy = :api_key # Default strategy for backward compatibility

      # OAuth2 credentials
      @oauth2_client_id = nil
      @oauth2_client_secret = nil
      @oauth2_token_url = nil
      @oauth2_scope = nil
    end

    # Set API key for authentication
    #
    # Supports loading from environment variable using :from_env symbol.
    #
    # @param value [String, Symbol, nil] The API key or :from_env
    #
    # @example Direct setting
    #   config.api_key = "special-key"
    #
    # @example From environment variable
    #   ENV['PETSTORE_API_KEY'] = "special-key"
    #   config.api_key = :from_env
    #
    def api_key=(value)
      @api_key = if value == :from_env
                   ENV.fetch(Authentication::ApiKey::ENV_VAR_NAME, nil)
                 else
                   value
                 end
    end

    # Build authenticator instance based on auth_strategy
    #
    # Returns appropriate authentication strategy based on auth_strategy setting:
    # - :none - No authentication
    # - :api_key - API Key authentication only
    # - :oauth2 - OAuth2 authentication only
    # - :both - Both API Key AND OAuth2 (composite)
    #
    # The authenticator is memoized and reused until reset_authenticator! is called.
    #
    # @return [Authentication::Base] Authentication strategy instance
    #
    # @raise [ConfigurationError] if auth_strategy is invalid
    #
    # @example
    #   config.auth_strategy = :oauth2
    #   config.authenticator # => #<OAuth2 client_id=...>
    #
    def authenticator
      @authenticator ||= build_authenticator
    end

    # Reset memoized authenticator
    #
    # Call this when configuration changes to rebuild the authenticator
    # with new settings.
    #
    # @return [void]
    #
    # @example
    #   config.auth_strategy = :api_key
    #   config.authenticator # => ApiKey instance
    #   config.auth_strategy = :oauth2
    #   config.reset_authenticator!
    #   config.authenticator # => OAuth2 instance
    #
    def reset_authenticator!
      @authenticator = nil
    end

    # Configure settings via block
    #
    # Yields self to the block for convenient configuration.
    # Automatically resets authenticator after configuration.
    #
    # @yieldparam [Configuration] self
    # @return [Configuration] self for method chaining
    #
    # @example
    #   config.configure do |c|
    #     c.api_key = "special-key"
    #     c.timeout = 60
    #     c.retry_enabled = false
    #   end
    #
    def configure
      yield(self) if block_given?
      reset_authenticator! # Rebuild authenticator when config changes
      self
    end

    # Validate configuration settings
    #
    # Checks that all required configuration is valid.
    # Currently validates:
    # - base_url is present
    # - authenticator is properly configured (if auth is enabled)
    #
    # @return [Boolean] true if valid
    # @raise [ValidationError] if configuration is invalid
    #
    # @example
    #   config = Configuration.new
    #   config.validate! # => true
    #
    #   config.base_url = nil
    #   config.validate! # raises ValidationError
    #
    def validate!
      raise ValidationError, "base_url can't be nil" if base_url.nil? || base_url.empty?

      # Validate authenticator if configured
      authenticator.is_a?(Authentication::ApiKey) && authenticator.configured?

      true
    end

    private

    # Build authentication strategy based on auth_strategy setting
    #
    # @return [Authentication::Base] Authentication strategy instance
    # @raise [ConfigurationError] if auth_strategy is invalid
    #
    def build_authenticator
      case @auth_strategy
      when :none
        build_none_authenticator
      when :api_key
        build_api_key_authenticator
      when :oauth2
        build_oauth2_authenticator
      when :both
        build_composite_authenticator
      else
        raise ConfigurationError,
              "Invalid auth_strategy: #{@auth_strategy.inspect}. " \
              "Must be one of: #{VALID_AUTH_STRATEGIES.map(&:inspect).join(", ")}"
      end
    end

    # Build None authenticator (no authentication)
    #
    # @return [Authentication::None]
    #
    def build_none_authenticator
      Authentication::None.new
    end

    # Build API Key authenticator
    #
    # Returns None authenticator if api_key is not configured.
    #
    # @return [Authentication::ApiKey, Authentication::None]
    #
    def build_api_key_authenticator
      if api_key.nil? || api_key.to_s.strip.empty?
        Authentication::None.new
      else
        Authentication::ApiKey.new(api_key)
      end
    end

    # Build OAuth2 authenticator
    #
    # Returns None authenticator if OAuth2 credentials are not configured.
    #
    # @return [Authentication::OAuth2, Authentication::None]
    #
    def build_oauth2_authenticator
      if oauth2_configured?
        Authentication::OAuth2.new(
          client_id: @oauth2_client_id,
          client_secret: @oauth2_client_secret,
          token_url: @oauth2_token_url || Authentication::OAuth2::DEFAULT_TOKEN_URL,
          scope: @oauth2_scope
        )
      else
        Authentication::None.new
      end
    end

    # Build Composite authenticator (both API Key and OAuth2)
    #
    # Creates a composite that applies both authentication methods simultaneously.
    # Only includes strategies that are actually configured.
    #
    # @return [Authentication::Composite]
    #
    def build_composite_authenticator
      strategies = []

      # Add API Key if configured
      unless api_key.nil? || api_key.to_s.strip.empty?
        strategies << Authentication::ApiKey.new(api_key)
      end

      # Add OAuth2 if configured
      if oauth2_configured?
        strategies << Authentication::OAuth2.new(
          client_id: @oauth2_client_id,
          client_secret: @oauth2_client_secret,
          token_url: @oauth2_token_url || Authentication::OAuth2::DEFAULT_TOKEN_URL,
          scope: @oauth2_scope
        )
      end

      Authentication::Composite.new(strategies)
    end

    # Check if OAuth2 credentials are configured
    #
    # @return [Boolean] true if client_id and client_secret are present
    #
    def oauth2_configured?
      !@oauth2_client_id.nil? && !@oauth2_client_id.to_s.strip.empty? &&
        !@oauth2_client_secret.nil? && !@oauth2_client_secret.to_s.strip.empty?
    end
  end
end
