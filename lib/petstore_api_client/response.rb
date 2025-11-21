# frozen_string_literal: true

module PetstoreApiClient
  # HTTP response wrapper for Petstore API responses
  #
  # Wraps Faraday HTTP responses and provides a clean, consistent interface
  # for accessing response data. This class implements the Single Responsibility
  # Principle by encapsulating all response handling logic in one place.
  #
  # The Response object provides:
  # - Parsed JSON body (automatically converted from JSON)
  # - HTTP status code
  # - Response headers
  # - Success/error detection
  # - Error message extraction
  # - Access to raw Faraday response
  #
  # Response bodies are automatically parsed from JSON. If the API returns
  # non-JSON content (like HTML error pages), the body is returned as a string.
  #
  # @example Accessing a successful response
  #   response = client.get("/pet/123")
  #   if response.success?
  #     pet = response.body
  #     puts pet["name"]
  #   end
  #
  # @example Handling an error response
  #   response = client.get("/pet/invalid")
  #   if response.error?
  #     puts response.error_message
  #     puts response.error_code
  #   end
  #
  # @see Request
  # @since 0.1.0
  class Response
    # @!attribute [r] status
    #   @return [Integer] HTTP status code (e.g., 200, 404, 500)
    # @!attribute [r] body
    #   @return [Hash, Array, String] Parsed response body
    # @!attribute [r] headers
    #   @return [Hash] HTTP response headers
    # @!attribute [r] raw_response
    #   @return [Faraday::Response] Original Faraday response object
    attr_reader :status, :body, :headers, :raw_response

    # Initialize a new Response wrapper
    #
    # Wraps a Faraday response object and extracts relevant data.
    # The response body is automatically parsed from JSON to Ruby objects.
    #
    # @param faraday_response [Faraday::Response] The Faraday response object
    #
    # @example
    #   faraday_response = connection.get("/pet/123")
    #   response = Response.new(faraday_response)
    #
    def initialize(faraday_response)
      @raw_response = faraday_response
      @status = faraday_response.status
      @body = parse_body(faraday_response.body)
      @headers = faraday_response.headers
    end

    # Check if the response was successful
    #
    # A response is considered successful if the HTTP status code is
    # in the 2xx range (200-299).
    #
    # @return [Boolean] true if status is 200-299, false otherwise
    #
    # @example
    #   response = client.get("/pet/123")
    #   if response.success?
    #     # Handle successful response
    #   end
    #
    def success?
      (200..299).cover?(status)
    end

    # Check if response indicates an error
    #
    # A response is considered an error if the HTTP status code is
    # outside the 2xx range.
    #
    # @return [Boolean] true if status is not 200-299, false otherwise
    #
    # @example
    #   response = client.get("/pet/invalid")
    #   if response.error?
    #     puts response.error_message
    #   end
    #
    def error?
      !success?
    end

    # Extract error message from response body
    #
    # Attempts to extract a human-readable error message from the response.
    # Handles various response formats:
    # - JSON with "message" key
    # - Plain text error messages
    # - HTML error pages
    # - Empty/nil responses
    #
    # @return [String, nil] Error message if response is an error, nil otherwise
    #
    # @example JSON error response
    #   # API returns: { "code": 404, "type": "NotFound", "message": "Pet not found" }
    #   response.error_message # => "Pet not found"
    #
    # @example HTML error response
    #   # API returns HTML error page
    #   response.error_message # => "Request failed with status 500"
    #
    def error_message
      return nil unless error?

      # Extract message from different response formats
      case body
      when Hash
        body["message"] || body[:message] || "Unknown error"
      when String
        # Sometimes the API returns HTML instead of JSON (sigh...)
        body.include?("<html>") ? "Request failed with status #{status}" : body
      else
        "Request failed with status #{status}"
      end
    end

    # Extract error code from response body
    #
    # Returns the error code from the response if available.
    # Falls back to HTTP status code if no error code is present in body.
    #
    # @return [Integer, nil] Error code if response is an error, nil otherwise
    #
    # @example
    #   # API returns: { "code": 1, "type": "NotFound", "message": "Pet not found" }
    #   response.error_code # => 1
    #
    def error_code
      return nil unless error?

      body.is_a?(Hash) ? (body["code"] || body[:code]) : status
    end

    # Extract error type from response body
    #
    # Returns the error type/category from the response if available.
    # This is useful for programmatic error handling.
    #
    # @return [String, nil] Error type if available, nil otherwise
    #
    # @example
    #   # API returns: { "code": 1, "type": "NotFound", "message": "Pet not found" }
    #   response.error_type # => "NotFound"
    #
    def error_type
      return nil unless error?

      body.is_a?(Hash) ? (body["type"] || body[:type]) : nil
    end

    private

    # Parse response body from JSON
    #
    # Handles JSON parsing and various edge cases:
    # - Already-parsed JSON (Hash/Array)
    # - Empty/nil responses
    # - Non-JSON responses (returns as-is)
    #
    # Faraday's JSON middleware typically handles parsing, but this method
    # provides additional safety for edge cases.
    #
    # @param body [Object] Raw response body
    # @return [Hash, Array, String, Object] Parsed body
    #
    # @api private
    def parse_body(body)
      # Faraday's JSON middleware already parses the response,
      # but we handle edge cases here
      return body if body.is_a?(Hash) || body.is_a?(Array)
      return {} if body.nil? || body.empty?

      body
    end
  end
end
