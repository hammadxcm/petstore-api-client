# frozen_string_literal: true

require_relative "base"

module PetstoreApiClient
  module Models
    # Base class for simple entities with just ID and name
    # Used by Category and Tag models to eliminate duplication
    #
    # This is an example of the DRY principle - both Category and Tag
    # were 100% identical, so we extracted their common behavior here.
    class NamedEntity < Base
      attribute :id, :integer
      attribute :name, :string

      # Override to_h to use symbol keys (API expects this format)
      def to_h
        {
          id: id,
          name: name
        }.compact
      end

      # Create from API response data
      # Handles both string and symbol keys
      def self.from_response(data)
        return nil if data.nil?

        new(
          id: extract_field(data, :id),
          name: extract_field(data, :name)
        )
      end
    end
  end
end
