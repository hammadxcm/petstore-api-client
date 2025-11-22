# frozen_string_literal: true

module PetstoreApiClient
  # Wrapper for paginated API responses
  # Provides metadata about pagination along with the data
  #
  # This follows the Decorator pattern - it wraps an array
  # with additional pagination information
  class PaginatedCollection
    include Enumerable

    attr_reader :data, :page, :per_page, :total_count

    # Initialize a paginated collection
    #
    # @param data [Array] The array of items for this page
    # @param page [Integer] Current page number (1-indexed)
    # @param per_page [Integer] Number of items per page
    # @param total_count [Integer, nil] Total number of items across all pages (if known)
    def initialize(data:, page: 1, per_page: 25, total_count: nil)
      @data = Array(data)
      @page = page.to_i
      @per_page = per_page.to_i
      @total_count = total_count&.to_i
    end

    # Delegate enumerable methods to data array
    def each(&block)
      data.each(&block)
    end

    # Number of items in current page
    def count
      data.count
    end
    alias size count
    alias length count

    # Check if there are more pages available
    # Returns true if we have total_count and current page isn't the last
    # Returns nil if total_count is unknown (can't determine)
    # rubocop:disable Style/ReturnNilInPredicateMethodDefinition
    def next_page?
      return nil if total_count.nil?

      page < total_pages
    end
    # rubocop:enable Style/ReturnNilInPredicateMethodDefinition

    # Check if there's a previous page
    def prev_page?
      page > 1
    end
    alias previous_page? prev_page?

    # Get next page number (nil if on last page or unknown)
    def next_page
      next_page? ? page + 1 : nil
    end

    # Get previous page number (nil if on first page)
    def prev_page
      prev_page? ? page - 1 : nil
    end
    alias previous_page prev_page

    # Calculate total number of pages
    # Returns nil if total_count is unknown
    def total_pages
      return nil if total_count.nil?
      return 1 if total_count.zero?

      (total_count.to_f / per_page).ceil
    end

    # Check if this is the first page
    def first_page?
      page == 1
    end

    # Check if this is the last page
    # Returns nil if total_count is unknown
    # rubocop:disable Style/ReturnNilInPredicateMethodDefinition
    def last_page?
      return nil if total_count.nil?

      page >= total_pages
    end
    # rubocop:enable Style/ReturnNilInPredicateMethodDefinition

    # Get offset for current page (0-indexed)
    def offset
      (page - 1) * per_page
    end

    # Check if collection is empty
    def empty?
      data.empty?
    end

    # Check if collection has any items
    def any?
      !empty?
    end

    # Convert to array (returns the data)
    def to_a
      data
    end
    alias to_ary to_a

    # Summary information about pagination
    def pagination_info
      {
        page: page,
        per_page: per_page,
        count: count,
        total_count: total_count,
        total_pages: total_pages,
        next_page: next_page,
        prev_page: prev_page,
        first_page: first_page?,
        last_page: last_page?
      }
    end

    # Inspect override for better debugging
    def inspect
      "#<PaginatedCollection page=#{page}/#{total_pages || "?"} " \
        "per_page=#{per_page} count=#{count} total=#{total_count || "?"}>"
    end
  end
end
