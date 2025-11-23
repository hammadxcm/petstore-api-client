# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Models::Tag do
  describe "#to_h" do
    it "converts tag to hash" do
      tag = described_class.new(id: 10, name: "friendly")
      expect(tag.to_h).to eq({ id: 10, name: "friendly" })
    end

    it "removes nil values" do
      tag = described_class.new(name: "friendly")
      expect(tag.to_h).to eq({ name: "friendly" })
    end

    it "handles empty tag" do
      tag = described_class.new
      expect(tag.to_h).to eq({})
    end
  end

  describe ".from_response" do
    it "creates tag from hash with string keys" do
      data = { "id" => 10, "name" => "friendly" }
      tag = described_class.from_response(data)

      expect(tag.id).to eq(10)
      expect(tag.name).to eq("friendly")
    end

    it "creates tag from hash with symbol keys" do
      data = { id: 20, name: "vaccinated" }
      tag = described_class.from_response(data)

      expect(tag.id).to eq(20)
      expect(tag.name).to eq("vaccinated")
    end

    it "returns nil for nil data" do
      expect(described_class.from_response(nil)).to be_nil
    end

    it "handles missing fields gracefully" do
      data = { "name" => "friendly" }
      tag = described_class.from_response(data)

      expect(tag.id).to be_nil
      expect(tag.name).to eq("friendly")
    end
  end
end
