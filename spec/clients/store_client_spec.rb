# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Clients::StoreClient do
  let(:config) { PetstoreApiClient::Configuration.new }
  let(:client) { described_class.new(config) }

  let(:mock_response) do
    double("Response",
           body: {
             "id" => 987,
             "petId" => 123,
             "quantity" => 2,
             "status" => "placed",
             "complete" => false
           })
  end

  describe "#create_order" do
    it "validates order data before making request" do
      invalid_data = { status: "invalid_status" }

      expect do
        client.create_order(invalid_data)
      end.to raise_error(PetstoreApiClient::ValidationError, /must be one of/)
    end

    it "builds order from hash and calls post endpoint" do
      order_data = { pet_id: 123, quantity: 1, status: "placed" }

      allow(client).to receive(:post).with("store/order", body: anything).and_return(mock_response)

      result = client.create_order(order_data)

      expect(result).to be_a(PetstoreApiClient::Models::Order)
      expect(result.pet_id).to eq(123)
    end

    it "accepts an Order object directly" do
      order = PetstoreApiClient::Models::Order.new(pet_id: 456, quantity: 2)

      allow(client).to receive(:post).and_return(mock_response)

      result = client.create_order(order)
      expect(result).to be_a(PetstoreApiClient::Models::Order)
    end

    it "properly converts order to API format with camelCase" do
      order_data = {
        pet_id: 789,
        quantity: 3,
        ship_date: DateTime.new(2025, 12, 25),
        status: "approved",
        complete: true
      }

      # Check the conversion to camelCase
      expect(client).to receive(:post) do |_path, body:|
        expect(body[:petId]).to eq(789)
        expect(body[:quantity]).to eq(3)
        expect(body[:shipDate]).to be_a(String) # ISO8601 format
        expect(body[:status]).to eq("approved")
        expect(body[:complete]).to be true
        mock_response
      end

      client.create_order(order_data)
    end

    it "handles orders without optional fields" do
      minimal_order = { pet_id: 123, quantity: 1 }

      allow(client).to receive(:post).and_return(mock_response)

      result = client.create_order(minimal_order)
      expect(result).to be_a(PetstoreApiClient::Models::Order)
    end
  end

  describe "#get_order" do
    it "validates order_id is an integer" do
      expect do
        client.get_order("not_an_id")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "validates order_id is not nil" do
      expect do
        client.get_order(nil)
      end.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    it "accepts string numeric IDs" do
      allow(client).to receive(:get).with("store/order/987").and_return(mock_response)

      result = client.get_order("987")
      expect(result).to be_a(PetstoreApiClient::Models::Order)
    end

    it "calls get endpoint with correct path" do
      expect(client).to receive(:get).with("store/order/555").and_return(mock_response)

      client.get_order(555)
    end

    it "returns an Order object from response" do
      allow(client).to receive(:get).and_return(mock_response)

      result = client.get_order(987)

      expect(result).to be_a(PetstoreApiClient::Models::Order)
      expect(result.id).to eq(987)
      expect(result.pet_id).to eq(123)
      expect(result.quantity).to eq(2)
    end
  end

  describe "#delete_order" do
    let(:delete_response) { double("Response", body: { "message" => "Order deleted" }) }

    it "validates order_id is present" do
      expect do
        client.delete_order(nil)
      end.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    it "validates order_id is numeric" do
      expect do
        client.delete_order("invalid")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "calls delete endpoint with correct path" do
      expect(client).to receive(:delete).with("store/order/888").and_return(delete_response)

      client.delete_order(888)
    end

    it "returns true on successful deletion" do
      allow(client).to receive(:delete).and_return(delete_response)

      result = client.delete_order(987)
      expect(result).to be true
    end
  end

  # Test ResourceOperations concern methods
  describe "ResourceOperations concern" do
    # Helper methods for shared examples
    let(:expected_model_class) { PetstoreApiClient::Models::Order }
    let(:expected_resource_name) { "store/order" }
    let(:expected_id_field_name) { "Order ID" }

    def build_valid_resource_data
      { pet_id: 123, quantity: 1 }
    end

    def build_valid_resource
      PetstoreApiClient::Models::Order.new(pet_id: 123, quantity: 1, status: "placed")
    end

    def build_invalid_resource
      PetstoreApiClient::Models::Order.new(pet_id: 123, status: "invalid")
    end

    # Use shared examples from resource_operations_examples.rb
    it_behaves_like "resource operations", "order"
  end
end
