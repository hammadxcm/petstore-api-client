# frozen_string_literal: true

module PetstoreApiClient
  module Models
    # ApiResponse model for structured error responses
    # Not used much since we raise exceptions instead of returning error objects
    class ApiResponse < Base
      attribute :code, :integer
      attribute :type, :string
      attribute :message, :string

      def to_h
        {
          code: code,
          type: type,
          message: message
        }.compact
      end

      def self.from_response(data)
        return nil if data.nil?

        new(
          code: data["code"] || data[:code],
          type: data["type"] || data[:type],
          message: data["message"] || data[:message]
        )
      end
    end
  end
end
