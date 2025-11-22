# frozen_string_literal: true

module PetstoreApiClient
  module Models
    # Order model representing a store order
    # TODO: Should validate quantity > 0 and pet_id presence, but assignment doc didn't specify
    class Order < Base
      VALID_STATUSES = %w[placed approved delivered].freeze

      attribute :id, :integer
      attribute :pet_id, :integer
      attribute :quantity, :integer
      attribute :ship_date, :datetime
      attribute :status, :string
      attribute :complete, :boolean, default: false

      validates :status, enum: { in: VALID_STATUSES, allow_nil: true }, if: -> { status.present? }

      # Note: API expects snake_case to be converted to camelCase
      def to_h
        {
          id: id,
          petId: pet_id,
          quantity: quantity,
          shipDate: ship_date&.iso8601,
          status: status,
          complete: complete
        }.compact
      end

      def self.from_response(data)
        return nil if data.nil?

        # Parse ship_date if it's a string
        ship_date = data["shipDate"] || data[:shipDate] || data[:ship_date]
        ship_date = parse_datetime(ship_date) if ship_date.is_a?(String)

        new(
          id: data["id"] || data[:id],
          pet_id: data["petId"] || data[:petId] || data[:pet_id],
          quantity: data["quantity"] || data[:quantity],
          ship_date: ship_date,
          status: data["status"] || data[:status],
          complete: data["complete"] || data[:complete] || false
        )
      end

      def self.parse_datetime(datetime_string)
        DateTime.parse(datetime_string)
      rescue ArgumentError
        nil # Silently fail - API shouldn't send invalid dates anyway
      end
    end
  end
end
