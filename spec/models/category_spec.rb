# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Models::Category do
  describe "#to_h" do
    it "converts category to hash" do
      category = described_class.new(id: 1, name: "Dogs")
      expect(category.to_h).to eq({ id: 1, name: "Dogs" })
    end

    it "removes nil values" do
      category = described_class.new(name: "Dogs")
      expect(category.to_h).to eq({ name: "Dogs" })
    end

    it "handles empty category" do
      category = described_class.new
      expect(category.to_h).to eq({})
    end
  end

  describe ".from_response" do
    it "creates category from hash with string keys" do
      data = { "id" => 1, "name" => "Dogs" }
      category = described_class.from_response(data)

      expect(category.id).to eq(1)
      expect(category.name).to eq("Dogs")
    end

    it "creates category from hash with symbol keys" do
      data = { id: 2, name: "Cats" }
      category = described_class.from_response(data)

      expect(category.id).to eq(2)
      expect(category.name).to eq("Cats")
    end

    it "returns nil for nil data" do
      expect(described_class.from_response(nil)).to be_nil
    end

    it "handles missing fields gracefully" do
      data = { "id" => 1 }
      category = described_class.from_response(data)

      expect(category.id).to eq(1)
      expect(category.name).to be_nil
    end
  end
end
