# frozen_string_literal: true

require_relative "named_entity"

module PetstoreApiClient
  module Models
    # Tag model - represents a pet tag
    # Inherits all behavior from NamedEntity (id + name)
    #
    # Refactored to eliminate 100% duplication with Category model
    # by inheriting from shared NamedEntity base class
    #
    # Keeping this as a separate class (rather than aliasing to Category)
    # in case we need to add tag-specific logic later
    class Tag < NamedEntity
      # Tag-specific logic can be added here if needed
      # For now, it just uses the base NamedEntity behavior
    end
  end
end
