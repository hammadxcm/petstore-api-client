# frozen_string_literal: true

module PetstoreApiClient
  # HTTP request methods for the Petstore API client
  #
  # Provides high-level abstraction over HTTP operations using Faraday.
  # This module implements the Dependency Inversion Principle by abstracting
  # HTTP operations behind a clean interface.
  #
  # All HTTP methods return a Response object that wraps the Faraday response.
  # Errors are automatically detected and raised as appropriate exception types.
  #
  # This module is included by Client and provides:
  # - GET requests for retrieving resources
  # - POST requests for creating resources
  # - PUT requests for updating resources
  # - DELETE requests for removing resources
  #
  # @example Making a GET request
  #   client = Client.new
  #   response = client.get("/pet/123")
  #   pet = response.body
  #
  # @example Making a POST request with body
  #   response = client.post("/pet", body: { name: "Fluffy", status: "available" })
  #
  # @see Connection
  # @see Response
  # @since 0.1.0
  module Request
    # Perform HTTP GET request
    #
    # Retrieves a resource from the API. Query parameters can be provided
    # via the params hash.
    #
    # @param path [String] The API endpoint path (e.g., "/pet/123")
    # @param params [Hash] Optional query parameters
    #
    # @return [Response] Wrapped HTTP response
    #
    # @raise [NotFoundError] if resource not found (404)
    # @raise [InvalidInputError] if request is invalid (400, 405)
    # @raise [RateLimitError] if rate limit exceeded (429)
    # @raise [ConnectionError] if connection fails or times out
    # @raise [ApiError] for other API errors
    #
    # @example Get a pet by ID
    #   response = client.get("/pet/123")
    #   pet = response.body
    #
    # @example Get pets with query parameters
    #   response = client.get("/pet/findByStatus", params: { status: "available" })
    #   pets = response.body
    #
    def get(path, params: {})
      request(:get, path, params: params)
    end

    # Perform HTTP POST request
    #
    # Creates a new resource on the API. The request body should contain
    # the resource data as a hash, which will be automatically serialized to JSON.
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body data
    #
    # @return [Response] Wrapped HTTP response
    #
    # @raise [InvalidInputError] if request body is invalid
    # @raise [ValidationError] if data fails validation
    # @raise [RateLimitError] if rate limit exceeded
    # @raise [ConnectionError] if connection fails or times out
    # @raise [ApiError] for other API errors
    #
    # @example Create a new pet
    #   response = client.post("/pet", body: {
    #     name: "Fluffy",
    #     status: "available",
    #     category: { id: 1, name: "Dogs" }
    #   })
    #
    def post(path, body: {})
      request(:post, path, body: body)
    end

    # Perform HTTP PUT request
    #
    # Updates an existing resource on the API. The request body should contain
    # the updated resource data as a hash.
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body data with updates
    #
    # @return [Response] Wrapped HTTP response
    #
    # @raise [NotFoundError] if resource not found (404)
    # @raise [InvalidInputError] if request body is invalid
    # @raise [ValidationError] if data fails validation
    # @raise [ConnectionError] if connection fails or times out
    # @raise [ApiError] for other API errors
    #
    # @example Update an existing pet
    #   response = client.put("/pet", body: {
    #     id: 123,
    #     name: "Fluffy Updated",
    #     status: "sold"
    #   })
    #
    def put(path, body: {})
      request(:put, path, body: body)
    end

    # Perform HTTP DELETE request
    #
    # Deletes a resource from the API. Query parameters can be provided
    # via the params hash if needed.
    #
    # @param path [String] The API endpoint path
    # @param params [Hash] Optional query parameters
    #
    # @return [Response] Wrapped HTTP response
    #
    # @raise [NotFoundError] if resource not found (404)
    # @raise [InvalidInputError] if request is invalid
    # @raise [ConnectionError] if connection fails or times out
    # @raise [ApiError] for other API errors
    #
    # @example Delete a pet
    #   response = client.delete("/pet/123")
    #
    def delete(path, params: {})
      request(:delete, path, params: params)
    end

    private

    # Core request method that handles all HTTP operations
    #
    # This is the central method that all public HTTP methods (get, post, put, delete)
    # delegate to. It handles:
    # - Executing the HTTP request via Faraday
    # - Wrapping the response in a Response object
    # - Error detection and exception raising
    # - Connection error handling
    #
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
    # @param path [String] API endpoint path
    # @param params [Hash] Query parameters for GET/DELETE requests
    # @param body [Hash] Request body for POST/PUT requests
    #
    # @return [Response] Wrapped HTTP response
    #
    # @raise [ConnectionError] if connection fails or times out
    # @raise [ApiError] for unexpected errors
    # @raise [NotFoundError, InvalidInputError, RateLimitError, etc.] for API errors
    #
    # @api private
    def request(method, path, params: {}, body: {})
      # puts "DEBUG: #{method.upcase} #{path}" if ENV['DEBUG']
      resp = connection.public_send(method) do |req|
        req.url path
        req.params = params if params.any?
        req.body = body if body.any?
      end

      wrapped_resp = Response.new(resp)
      handle_error_response(wrapped_resp) if wrapped_resp.error?

      wrapped_resp
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError, "Connection failed: #{e.message}"
    rescue Faraday::TimeoutError => e
      raise ConnectionError, "Request timeout: #{e.message}"
    rescue Error
      # Don't double-wrap our own errors
      raise
    rescue StandardError => e
      # Catch-all for unexpected errors
      raise ApiError, "Request failed: #{e.message}"
    end

    # Handle error responses and raise appropriate exceptions
    #
    # Examines the HTTP status code and error message from the API response
    # and raises the appropriate exception type. This provides a clean
    # abstraction where callers can rescue specific error types.
    #
    # Status code mapping:
    # - 404: NotFoundError
    # - 400: InvalidOrderError (if error_type is "InvalidOrder") or InvalidInputError
    # - 405: InvalidInputError
    # - 429: RateLimitError (includes retry-after header)
    # - Other: ApiError
    #
    # @param response [Response] The wrapped HTTP response
    # @return [void]
    #
    # @raise [NotFoundError] for 404 responses
    # @raise [InvalidInputError] for 400/405 responses
    # @raise [InvalidOrderError] for 400 responses with InvalidOrder error type
    # @raise [RateLimitError] for 429 responses
    # @raise [ApiError] for other error responses
    #
    # @api private
    def handle_error_response(response)
      case response.status
      when 404
        raise NotFoundError, response.error_message
      when 400
        # Check if it's an order-related error
        raise InvalidOrderError, response.error_message if response.error_type == "InvalidOrder"

        raise InvalidInputError, response.error_message
      when 405
        raise InvalidInputError, response.error_message
      when 429
        # Rate limiting - extract retry-after header if present
        retry_after = response.headers["retry-after"] || response.headers["Retry-After"]
        raise RateLimitError.new(response.error_message, retry_after: retry_after)
      else
        raise ApiError, response.error_message
      end
    end
  end
end
