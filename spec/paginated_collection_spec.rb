# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::PaginatedCollection do
  let(:data) { [1, 2, 3, 4, 5] }
  let(:collection) { described_class.new(data: data, page: 1, per_page: 2, total_count: 10) }

  describe "#initialize" do
    it "initializes with data and pagination params" do
      expect(collection.data).to eq([1, 2, 3, 4, 5])
      expect(collection.page).to eq(1)
      expect(collection.per_page).to eq(2)
      expect(collection.total_count).to eq(10)
    end

    it "converts page and per_page to integers" do
      col = described_class.new(data: data, page: "2", per_page: "5")
      expect(col.page).to eq(2)
      expect(col.per_page).to eq(5)
    end

    it "handles nil total_count" do
      col = described_class.new(data: data, page: 1, per_page: 2)
      expect(col.total_count).to be_nil
    end
  end

  describe "#count" do
    it "returns the number of items in current page" do
      expect(collection.count).to eq(5)
    end
  end

  describe "#next_page?" do
    it "returns true when there are more pages" do
      expect(collection.next_page?).to be true
    end

    it "returns false when on last page" do
      col = described_class.new(data: data, page: 5, per_page: 2, total_count: 10)
      expect(col.next_page?).to be false
    end

    it "returns nil when total_count is unknown" do
      col = described_class.new(data: data, page: 1, per_page: 2)
      expect(col.next_page?).to be_nil
    end
  end

  describe "#prev_page?" do
    it "returns false on first page" do
      expect(collection.prev_page?).to be false
    end

    it "returns true when not on first page" do
      col = described_class.new(data: data, page: 2, per_page: 2, total_count: 10)
      expect(col.prev_page?).to be true
    end
  end

  describe "#next_page" do
    it "returns next page number" do
      expect(collection.next_page).to eq(2)
    end

    it "returns nil when on last page" do
      col = described_class.new(data: data, page: 5, per_page: 2, total_count: 10)
      expect(col.next_page).to be_nil
    end
  end

  describe "#prev_page" do
    it "returns nil on first page" do
      expect(collection.prev_page).to be_nil
    end

    it "returns previous page number" do
      col = described_class.new(data: data, page: 3, per_page: 2, total_count: 10)
      expect(col.prev_page).to eq(2)
    end
  end

  describe "#total_pages" do
    it "calculates total pages from total_count" do
      expect(collection.total_pages).to eq(5) # 10 items / 2 per_page = 5 pages
    end

    it "returns nil when total_count is unknown" do
      col = described_class.new(data: data, page: 1, per_page: 2)
      expect(col.total_pages).to be_nil
    end

    it "handles uneven division (rounds up)" do
      col = described_class.new(data: data, page: 1, per_page: 3, total_count: 10)
      expect(col.total_pages).to eq(4) # 10 / 3 = 3.33 -> 4 pages
    end
  end

  describe "#first_page?" do
    it "returns true on first page" do
      expect(collection.first_page?).to be true
    end

    it "returns false when not on first page" do
      col = described_class.new(data: data, page: 2, per_page: 2, total_count: 10)
      expect(col.first_page?).to be false
    end
  end

  describe "#last_page?" do
    it "returns false when not on last page" do
      expect(collection.last_page?).to be false
    end

    it "returns true on last page" do
      col = described_class.new(data: data, page: 5, per_page: 2, total_count: 10)
      expect(col.last_page?).to be true
    end

    it "returns nil when total_count is unknown" do
      col = described_class.new(data: data, page: 1, per_page: 2)
      expect(col.last_page?).to be_nil
    end
  end

  describe "#offset" do
    it "calculates offset for first page" do
      expect(collection.offset).to eq(0) # (1-1) * 2 = 0
    end

    it "calculates offset for subsequent pages" do
      col = described_class.new(data: data, page: 3, per_page: 5, total_count: 20)
      expect(col.offset).to eq(10) # (3-1) * 5 = 10
    end
  end

  describe "#empty?" do
    it "returns false when data is present" do
      expect(collection.empty?).to be false
    end

    it "returns true when data is empty" do
      col = described_class.new(data: [], page: 1, per_page: 2)
      expect(col.empty?).to be true
    end
  end

  describe "#any?" do
    it "returns true when data is present" do
      expect(collection.any?).to be true
    end

    it "returns false when data is empty" do
      col = described_class.new(data: [], page: 1, per_page: 2)
      expect(col.any?).to be false
    end
  end

  describe "#to_a" do
    it "returns the data array" do
      expect(collection.to_a).to eq([1, 2, 3, 4, 5])
    end
  end

  describe "#pagination_info" do
    it "returns pagination metadata" do
      info = collection.pagination_info

      expect(info[:page]).to eq(1)
      expect(info[:per_page]).to eq(2)
      expect(info[:count]).to eq(5)
      expect(info[:total_count]).to eq(10)
      expect(info[:total_pages]).to eq(5)
      expect(info[:next_page]).to eq(2)
      expect(info[:prev_page]).to be_nil
      expect(info[:first_page]).to be true
      expect(info[:last_page]).to be false
    end
  end

  describe "Enumerable methods" do
    it "supports map" do
      result = collection.map { |n| n * 2 }
      expect(result).to eq([2, 4, 6, 8, 10])
    end

    it "supports select" do
      result = collection.select(&:odd?)
      expect(result).to eq([1, 3, 5])
    end

    it "supports each" do
      sum = 0
      collection.each { |n| sum += n }
      expect(sum).to eq(15)
    end
  end

  describe "#inspect" do
    it "returns helpful debugging info" do
      expect(collection.inspect).to include("page=1/5")
      expect(collection.inspect).to include("per_page=2")
      expect(collection.inspect).to include("count=5")
      expect(collection.inspect).to include("total=10")
    end

    it "shows question mark for unknown total" do
      col = described_class.new(data: data, page: 1, per_page: 2)
      expect(col.inspect).to include("page=1/?")
      expect(col.inspect).to include("total=?")
    end
  end
end
