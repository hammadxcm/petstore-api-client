# frozen_string_literal: true

module PetstoreApiClient
  # Base error class - all our exceptions inherit from this
  class Error < StandardError
    attr_reader :status_code, :error_type

    def initialize(message = nil, status_code: nil, error_type: nil)
      @status_code = status_code
      @error_type = error_type
      super(message)
    end
  end

  # Validation errors - thrown before we even hit the API
  class ValidationError < Error; end

  # Configuration errors - thrown when configuration is invalid
  # @since 0.2.0
  class ConfigurationError < Error; end

  # Authentication errors - thrown when authentication fails
  # @since 0.2.0
  class AuthenticationError < Error
    def initialize(message = "Authentication failed")
      super(message, status_code: 401, error_type: "Authentication")
    end
  end

  # 404 errors
  class NotFoundError < Error
    def initialize(message = "Resource not found")
      super(message, status_code: 404, error_type: "NotFound")
    end
  end

  # 405 or 400 errors for bad input
  class InvalidInputError < Error
    def initialize(message = "Invalid input provided")
      super(message, status_code: 405, error_type: "InvalidInput")
    end
  end

  # 400 errors specific to orders
  class InvalidOrderError < Error
    def initialize(message = "Invalid order supplied")
      super(message, status_code: 400, error_type: "InvalidOrder")
    end
  end

  # Network/connection issues
  class ConnectionError < Error
    def initialize(message = "Failed to connect to the API")
      super(message, status_code: nil, error_type: "Connection")
    end
  end

  # Rate limiting errors - too many requests
  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message = "Rate limit exceeded", retry_after: nil)
      @retry_after = retry_after
      super(message, status_code: 429, error_type: "RateLimit")
    end
  end

  # Catch-all for other API errors
  class ApiError < Error; end
end
