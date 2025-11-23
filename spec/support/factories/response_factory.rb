# frozen_string_literal: true

module ResponseFactory
  # Builds a mock Faraday::Env object for authentication testing
  #
  # @param scheme [String] URL scheme ('http' or 'https')
  # @param headers [Hash] Request headers
  # @return [Double] Mock Faraday::Env object
  def build_faraday_env(scheme: "https", headers: {})
    url = double("URL", scheme: scheme)
    double("Faraday::Env", request_headers: headers, url: url)
  end

  # Builds a mock HTTP response object
  #
  # @param body [Hash, String] Response body
  # @param status [Integer] HTTP status code
  # @param headers [Hash] Response headers
  # @return [Double] Mock response object
  def build_mock_response(body:, status: 200, headers: {})
    double("Response",
           body: body,
           status: status,
           headers: headers,
           success?: status >= 200 && status < 300)
  end

  # Builds a mock pet response
  #
  # @param id [Integer] Pet ID
  # @param name [String] Pet name
  # @param status [String] Pet status
  # @param photo_urls [Array<String>] Photo URLs
  # @param category [Hash, nil] Category data
  # @param tags [Array<Hash>, nil] Tag data
  # @return [Double] Mock response with pet data
  def build_pet_response(id: 123, name: "Fluffy", status: "available",
                         photo_urls: ["https://example.com/fluffy.jpg"],
                         category: nil, tags: nil)
    body = {
      "id" => id,
      "name" => name,
      "photoUrls" => photo_urls,
      "status" => status
    }

    body["category"] = category if category
    body["tags"] = tags if tags

    build_mock_response(body: body)
  end

  # Builds a mock order response
  #
  # @param id [Integer] Order ID
  # @param pet_id [Integer] Pet ID
  # @param quantity [Integer] Quantity ordered
  # @param status [String] Order status
  # @param complete [Boolean] Whether order is complete
  # @return [Double] Mock response with order data
  def build_order_response(id: 456, pet_id: 123, quantity: 1,
                           status: "placed", complete: false)
    body = {
      "id" => id,
      "petId" => pet_id,
      "quantity" => quantity,
      "status" => status,
      "complete" => complete
    }

    build_mock_response(body: body)
  end

  # Builds a mock error response
  #
  # @param status [Integer] HTTP status code
  # @param message [String] Error message
  # @param error_type [String, nil] Error type
  # @return [Double] Mock error response
  def build_error_response(status: 400, message: "Error occurred", error_type: nil)
    body = {
      "code" => status,
      "message" => message
    }

    body["type"] = error_type if error_type

    build_mock_response(body: body, status: status)
  end

  # Builds a mock delete response
  #
  # @param message [String] Success message
  # @return [Double] Mock response for delete operations
  def build_delete_response(message: "Resource deleted")
    build_mock_response(body: { "message" => message })
  end

  # Builds a mock paginated response
  #
  # @param items [Array] Array of items
  # @param total [Integer, nil] Total count
  # @param page [Integer, nil] Current page
  # @return [Double] Mock paginated response
  def build_paginated_response(items: [], total: nil, page: nil)
    body = { "items" => items }
    body["total"] = total if total
    body["page"] = page if page

    build_mock_response(body: body)
  end

  # Builds a mock OAuth2 access token
  #
  # @param token [String] Access token value
  # @param expires_in [Integer] Seconds until expiration
  # @param expires_at [Time, nil] Absolute expiration time
  # @return [Double] Mock OAuth2::AccessToken
  def build_oauth2_token(token: "mock_access_token", expires_in: 3600, expires_at: nil)
    expires_at ||= Time.now + expires_in

    double("OAuth2::AccessToken",
           token: token,
           expires?: true,
           expires_at: expires_at.to_i,
           expired?: false)
  end
end

# Include factory in all specs
RSpec.configure do |config|
  config.include ResponseFactory
end
