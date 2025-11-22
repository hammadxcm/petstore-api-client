# frozen_string_literal: true

module PetstoreApiClient
  module Models
    # Pet resource model
    #
    # Represents a pet in the Petstore API with comprehensive validations
    # following the API specification. Uses ActiveModel for validation,
    # attribute management, and serialization.
    #
    # The Pet model supports:
    # - Required and optional attributes with type casting
    # - Nested objects (Category, Tags)
    # - Status enum validation
    # - Bi-directional conversion (to API format and from API responses)
    # - ActiveModel validations
    #
    # @example Creating a new pet
    #   pet = Pet.new(
    #     name: "Fluffy",
    #     status: "available",
    #     photo_urls: ["https://example.com/photo1.jpg"]
    #   )
    #
    # @example Creating a pet with nested category
    #   pet = Pet.new(
    #     name: "Fluffy",
    #     status: "available",
    #     category: { id: 1, name: "Dogs" },
    #     tags: [{ id: 1, name: "friendly" }],
    #     photo_urls: ["https://example.com/photo1.jpg"]
    #   )
    #
    # @example Creating from API response
    #   data = { "id" => 123, "name" => "Fluffy", "status" => "available" }
    #   pet = Pet.from_response(data)
    #
    # @example Converting to API format
    #   pet_hash = pet.to_h
    #   # Returns: { id: 123, name: "Fluffy", photoUrls: [...], status: "available" }
    #
    # @see Category
    # @see Tag
    # @since 0.1.0
    class Pet < Base
      # Valid pet status values per API specification
      VALID_STATUSES = %w[available pending sold].freeze

      # @!attribute [rw] id
      #   @return [Integer, nil] Pet ID (assigned by server)
      attribute :id, :integer

      # @!attribute [rw] name
      #   @return [String] Pet name (required)
      attribute :name, :string

      # @!attribute [rw] photo_urls
      #   @return [Array<String>] URLs of pet photos (required, minimum 1)
      attribute :photo_urls, default: -> { [] }

      # @!attribute [rw] status
      #   @return [String, nil] Pet status (available, pending, or sold)
      attribute :status, :string

      # @!attribute [rw] category
      #   @return [Category, nil] Pet category (optional nested object)
      # @!attribute [rw] tags
      #   @return [Array<Tag>] Pet tags (optional nested objects)
      attr_accessor :category, :tags

      # Validations per API specification
      validates :name, presence: true, length: { minimum: 1 }
      validates :photo_urls, array_presence: true
      validates :status, enum: { in: VALID_STATUSES, allow_nil: true }, if: -> { status.present? }

      # Validate nested category if present
      validate :category_valid, if: -> { category.present? }

      # Validate nested tags if present
      validate :tags_valid, if: -> { tags.present? && tags.any? }

      # Initialize a new Pet model
      #
      # Accepts attributes as a hash and builds nested Category and Tag objects
      # if provided. Handles both symbol and string keys.
      #
      # @param attributes [Hash] Pet attributes
      # @option attributes [Integer] :id Pet ID (optional, assigned by server)
      # @option attributes [String] :name Pet name (required)
      # @option attributes [Array<String>] :photo_urls Photo URLs (required)
      # @option attributes [String] :status Pet status (available, pending, sold)
      # @option attributes [Hash, Category] :category Category data or object
      # @option attributes [Array<Hash>, Array<Tag>] :tags Array of tag data or objects
      #
      # @example
      #   pet = Pet.new(name: "Fluffy", photo_urls: ["http://example.com/1.jpg"])
      #
      def initialize(attributes = {})
        # Handle category separately since it's a nested object
        category_data = attributes.delete(:category) || attributes.delete("category")
        @category = build_category(category_data) if category_data

        # Handle tags separately since they're nested objects
        tags_data = attributes.delete(:tags) || attributes.delete("tags")
        @tags = build_tags(tags_data) if tags_data

        super
      end

      # Convert pet to hash for API requests
      #
      # Converts the pet object to a hash suitable for API requests.
      # Uses camelCase keys as expected by the Petstore API.
      # Nested objects (category, tags) are also converted to hashes.
      # Nil values are removed from the output.
      #
      # @return [Hash] Pet data in API format with camelCase keys
      #
      # @example
      #   pet = Pet.new(name: "Fluffy", photo_urls: ["http://example.com/1.jpg"])
      #   pet.to_h
      #   # => { name: "Fluffy", photoUrls: ["http://example.com/1.jpg"] }
      #
      def to_h
        # puts "Converting pet to hash: #{name}" if ENV['DEBUG']
        {
          id: id,
          category: category&.to_h,
          name: name,
          photoUrls: photo_urls, # camelCase for API
          tags: tags&.map(&:to_h),
          status: status
        }.compact # Remove nil values
      end

      # Create Pet instance from API response data
      #
      # Factory method that creates a Pet object from API response data.
      # Handles both string and symbol keys, and converts camelCase API
      # keys (photoUrls) to snake_case Ruby convention (photo_urls).
      #
      # @param data [Hash, nil] API response data
      # @return [Pet, nil] New Pet instance, or nil if data is nil
      #
      # @example
      #   response_data = {
      #     "id" => 123,
      #     "name" => "Fluffy",
      #     "photoUrls" => ["http://example.com/1.jpg"],
      #     "status" => "available"
      #   }
      #   pet = Pet.from_response(response_data)
      #
      def self.from_response(data)
        return nil if data.nil?

        new(
          id: data["id"] || data[:id],
          name: data["name"] || data[:name],
          photo_urls: data["photoUrls"] || data[:photoUrls] || data[:photo_urls],
          category: data["category"] || data[:category],
          tags: data["tags"] || data[:tags],
          status: data["status"] || data[:status]
        )
      end

      private

      # Build Category object from data
      #
      # @param category_data [Hash, Category, nil] Category data or object
      # @return [Category, nil] Category instance or nil
      # @api private
      def build_category(category_data)
        return nil if category_data.nil?
        return category_data if category_data.is_a?(Category)

        Category.new(category_data)
      end

      # Build array of Tag objects from data
      #
      # @param tags_data [Array<Hash>, Array<Tag>, nil] Array of tag data or objects
      # @return [Array<Tag>] Array of Tag instances
      # @api private
      def build_tags(tags_data)
        return [] if tags_data.nil? || !tags_data.is_a?(Array)

        tags_data.map do |tag_data|
          tag_data.is_a?(Tag) ? tag_data : Tag.new(tag_data)
        end
      end

      # Validate nested category object
      #
      # Custom validator that checks if the nested category is valid.
      # Adds error messages from category to this pet's errors.
      #
      # @return [void]
      # @api private
      def category_valid
        return unless category.present?
        return if category.valid?

        errors.add(:category, "is invalid: #{category.errors.full_messages.join(", ")}")
      end

      # Validate nested tag objects
      #
      # Custom validator that checks if all tags are valid.
      # Adds error if any tags are invalid.
      #
      # @return [void]
      # @api private
      def tags_valid
        return unless tags.is_a?(Array)

        invalid_tags = tags.reject(&:valid?)
        return if invalid_tags.empty?

        errors.add(:tags, "contain invalid entries")
      end
    end
  end
end
