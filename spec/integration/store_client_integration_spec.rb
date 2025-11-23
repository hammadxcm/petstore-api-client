# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Store Client Integration", :vcr do
  let(:client) { PetstoreApiClient::ApiClient.new }
  let(:store_client) { client.store }

  let(:valid_order_data) do
    {
      id: 98_765,
      pet_id: 123,
      quantity: 2,
      ship_date: DateTime.new(2025, 1, 15, 10, 0, 0),
      status: "placed",
      complete: false
    }
  end

  describe "#create_order", vcr: { cassette_name: "store_client/create_order_success" } do
    it "creates a new order successfully" do
      order = store_client.create_order(valid_order_data)

      expect(order).to be_a(PetstoreApiClient::Models::Order)
      expect(order.pet_id).to eq(123)
      expect(order.quantity).to eq(2)
      expect(order.status).to eq("placed")
      expect(order.complete).to eq(false)
    end
  end

  describe "#create_order with invalid data" do
    it "raises ValidationError for invalid status", vcr: { cassette_name: "store_client/create_order_invalid" } do
      invalid_order = valid_order_data.merge(status: "invalid_status")

      expect do
        store_client.create_order(invalid_order)
      end.to raise_error(PetstoreApiClient::ValidationError, /must be one of/)
    end
  end

  describe "#get_order", vcr: { cassette_name: "store_client/get_order_success" } do
    it "retrieves an order by ID successfully" do
      # Create an order first
      created_order = store_client.create_order(valid_order_data)

      # Retrieve it
      fetched_order = store_client.get_order(created_order.id)

      expect(fetched_order).to be_a(PetstoreApiClient::Models::Order)
      expect(fetched_order.id).to eq(created_order.id)
      expect(fetched_order.pet_id).to eq(created_order.pet_id)
    end
  end

  describe "#get_order with non-existent ID" do
    it "raises NotFoundError", vcr: { cassette_name: "store_client/get_order_not_found" } do
      expect do
        store_client.get_order(999_999_999)
      end.to raise_error(PetstoreApiClient::NotFoundError)
    end
  end

  describe "#delete_order", vcr: { cassette_name: "store_client/delete_order_success" } do
    it "deletes an order successfully" do
      # Create an order first
      created_order = store_client.create_order(valid_order_data)

      # Delete it
      result = store_client.delete_order(created_order.id)

      expect(result).to be true
    end
  end

  describe "#delete_order with non-existent ID" do
    it "raises NotFoundError", vcr: { cassette_name: "store_client/delete_order_not_found" } do
      expect do
        store_client.delete_order(999_999_999)
      end.to raise_error(PetstoreApiClient::NotFoundError)
    end
  end

  describe "validation before API call" do
    it "validates order ID is an integer" do
      expect do
        store_client.get_order("not_a_number")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "validates order ID is not nil" do
      expect { store_client.delete_order(nil) }.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    # TODO: Add test for negative quantity orders
    # it "validates quantity is positive" do
    #   # Need to implement quantity validation first
    # end
  end
end
