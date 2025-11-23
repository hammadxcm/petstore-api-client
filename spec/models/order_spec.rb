# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Models::Order do
  describe "validations" do
    it "is valid with basic attributes" do
      order = described_class.new(
        id: 987,
        pet_id: 123,
        quantity: 2
      )
      expect(order).to be_valid
    end

    # Currently no validation on quantity or pet_id since assignment didn't specify
    # Should probably add these in a future version

    describe "status validation" do
      it "is valid with 'placed' status" do
        order = described_class.new(status: "placed")
        expect(order).to be_valid
      end

      it "is valid with 'approved' status" do
        order = described_class.new(status: "approved")
        expect(order).to be_valid
      end

      it "is valid with 'delivered' status" do
        order = described_class.new(status: "delivered")
        expect(order).to be_valid
      end

      it "is valid with nil status" do
        order = described_class.new(status: nil)
        expect(order).to be_valid
      end

      it "is invalid with an invalid status" do
        order = described_class.new(status: "invalid")
        expect(order).not_to be_valid
        expect(order.errors[:status].first).to match(/must be one of/)
      end
    end
  end

  describe "#to_h" do
    it "converts the order to a hash with camelCase keys" do
      ship_date = DateTime.new(2025, 1, 2, 10, 0, 0)
      order = described_class.new(
        id: 987,
        pet_id: 123,
        quantity: 2,
        ship_date: ship_date,
        status: "placed",
        complete: false
      )

      hash = order.to_h
      expect(hash[:id]).to eq(987)
      expect(hash[:petId]).to eq(123)
      expect(hash[:quantity]).to eq(2)
      expect(hash[:shipDate]).to eq(ship_date.iso8601)
      expect(hash[:status]).to eq("placed")
      expect(hash[:complete]).to eq(false)
    end
  end

  describe ".from_response" do
    it "creates an Order from API response data" do
      data = {
        "id" => 987,
        "petId" => 123,
        "quantity" => 2,
        "shipDate" => "2025-01-02T10:00:00Z",
        "status" => "placed",
        "complete" => false
      }

      order = described_class.from_response(data)
      expect(order.id).to eq(987)
      expect(order.pet_id).to eq(123)
      expect(order.quantity).to eq(2)
      expect(order.ship_date).to be_a(DateTime)
      expect(order.status).to eq("placed")
      expect(order.complete).to eq(false)
    end

    it "returns nil for nil data" do
      expect(described_class.from_response(nil)).to be_nil
    end

    it "handles invalid datetime strings gracefully" do
      data = {
        "id" => 987,
        "shipDate" => "invalid-date"
      }

      order = described_class.from_response(data)
      expect(order.ship_date).to be_nil
    end
  end
end
