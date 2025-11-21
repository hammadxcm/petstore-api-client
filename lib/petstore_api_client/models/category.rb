# frozen_string_literal: true

require_relative "named_entity"

module PetstoreApiClient
  module Models
    # Category model - represents a pet category
    # Inherits all behavior from NamedEntity (id + name)
    #
    # Refactored to eliminate 100% duplication with Tag model
    # by inheriting from shared NamedEntity base class
    class Category < NamedEntity
      # Category-specific logic can be added here if needed
      # For now, it just uses the base NamedEntity behavior
    end
  end
end
