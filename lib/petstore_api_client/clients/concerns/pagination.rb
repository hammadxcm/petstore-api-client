# frozen_string_literal: true

module PetstoreApiClient
  module Clients
    module Concerns
      # Pagination support for list endpoints
      # Provides utilities for handling pagination parameters and responses
      #
      # This module follows the Strategy pattern - it encapsulates
      # different pagination strategies (offset-based, page-based)
      module Pagination
        # Default pagination settings
        DEFAULT_PAGE = 1
        DEFAULT_PER_PAGE = 25
        MAX_PER_PAGE = 100

        private

        # Normalize pagination options from various input formats
        # Supports both page-based (page, per_page) and offset-based (offset, limit)
        #
        # @param options [Hash] Input options
        # @option options [Integer] :page Page number (1-indexed)
        # @option options [Integer] :per_page Items per page
        # @option options [Integer] :offset Offset for results (0-indexed)
        # @option options [Integer] :limit Maximum number of results
        # @return [Hash] Normalized pagination params with :page and :per_page
        # rubocop:disable Metrics/MethodLength
        def normalize_pagination_options(options = {})
          # Handle offset-based pagination
          if options.key?(:offset) || options.key?(:limit)
            offset = (options[:offset] || 0).to_i
            limit = (options[:limit] || DEFAULT_PER_PAGE).to_i

            # Convert offset/limit to page/per_page
            page = (offset / limit) + 1
            per_page = limit
          else
            # Handle page-based pagination (default)
            page = (options[:page] || DEFAULT_PAGE).to_i
            per_page = (options[:per_page] || DEFAULT_PER_PAGE).to_i
          end

          # Validate and constrain values
          page = 1 if page < 1
          per_page = DEFAULT_PER_PAGE if per_page < 1
          per_page = MAX_PER_PAGE if per_page > MAX_PER_PAGE

          {
            page: page,
            per_page: per_page,
            offset: (page - 1) * per_page,
            limit: per_page
          }
        end
        # rubocop:enable Metrics/MethodLength

        # Create a PaginatedCollection from array data
        #
        # @param data [Array] Array of items
        # @param pagination_opts [Hash] Pagination options
        # @option pagination_opts [Integer] :page Current page number
        # @option pagination_opts [Integer] :per_page Items per page
        # @option pagination_opts [Integer] :total_count Total items (if known)
        # @return [PaginatedCollection] Wrapped collection with pagination metadata
        def paginated_collection(data, pagination_opts = {})
          PaginatedCollection.new(
            data: data,
            page: pagination_opts[:page] || DEFAULT_PAGE,
            per_page: pagination_opts[:per_page] || DEFAULT_PER_PAGE,
            total_count: pagination_opts[:total_count]
          )
        end

        # Apply client-side pagination to an array
        # Used when API returns all results and we need to paginate locally
        #
        # @param items [Array] Full array of items
        # @param options [Hash] Pagination options
        # @return [PaginatedCollection] Paginated subset of items
        def apply_client_side_pagination(items, options = {})
          pagination_opts = normalize_pagination_options(options)
          offset = pagination_opts[:offset]
          limit = pagination_opts[:per_page]

          # Slice the array based on offset and limit
          page_data = items[offset, limit] || []

          paginated_collection(
            page_data,
            page: pagination_opts[:page],
            per_page: pagination_opts[:per_page],
            total_count: items.length
          )
        end

        # Build query parameters for API requests with pagination
        # Converts internal pagination format to API-specific format
        #
        # @param options [Hash] Pagination options
        # @param api_format [Symbol] API pagination format (:offset_limit or :page_per_page)
        # @return [Hash] Query parameters for API request
        def build_pagination_params(options = {}, api_format: :offset_limit)
          pagination_opts = normalize_pagination_options(options)

          case api_format
          when :offset_limit
            {
              offset: pagination_opts[:offset],
              limit: pagination_opts[:limit]
            }
          when :page_per_page
            {
              page: pagination_opts[:page],
              per_page: pagination_opts[:per_page]
            }
          else
            raise ArgumentError, "Unknown API format: #{api_format}"
          end
        end
      end
    end
  end
end
