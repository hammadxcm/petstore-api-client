# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::ApiClient do
  let(:client) { described_class.new }

  describe "#initialize" do
    it "creates a new client with default configuration" do
      expect(client.configuration).to be_a(PetstoreApiClient::Configuration)
      expect(client.configuration.base_url).to eq("https://petstore.swagger.io/v2")
    end

    it "accepts a custom configuration" do
      custom_config = PetstoreApiClient::Configuration.new
      custom_config.base_url = "https://custom-api.com"

      client_with_config = described_class.new(custom_config)

      expect(client_with_config.configuration.base_url).to eq("https://custom-api.com")
    end

    it "validates configuration on initialization" do
      invalid_config = PetstoreApiClient::Configuration.new
      invalid_config.base_url = nil

      expect do
        described_class.new(invalid_config)
      end.to raise_error(PetstoreApiClient::ValidationError, /base_url/)
    end
  end

  describe "#configure" do
    it "allows configuration via block" do
      client.configure do |config|
        config.api_key = "test-key"
        config.timeout = 60
      end

      expect(client.configuration.api_key).to eq("test-key")
      expect(client.configuration.timeout).to eq(60)
    end

    it "returns self for method chaining" do
      result = client.configure { |c| c.timeout = 45 }
      expect(result).to be(client)
    end

    # Note: Configuration changes affect the existing client instances
    # since they share the same configuration object. This is intentional -
    # we don't need to reset the client instances, just update the config.
  end

  describe "#pets" do
    it "returns a PetClient instance" do
      expect(client.pets).to be_a(PetstoreApiClient::Clients::PetClient)
    end

    it "memoizes the PetClient instance" do
      pets1 = client.pets
      pets2 = client.pets

      expect(pets1).to be(pets2)
    end

    it "passes configuration to PetClient" do
      client.configure { |c| c.api_key = "my-key" }

      pets_client = client.pets

      expect(pets_client.configuration.api_key).to eq("my-key")
    end
  end

  describe "#store" do
    it "returns a StoreClient instance" do
      expect(client.store).to be_a(PetstoreApiClient::Clients::StoreClient)
    end

    it "memoizes the StoreClient instance" do
      store1 = client.store
      store2 = client.store

      expect(store1).to be(store2)
    end

    it "passes configuration to StoreClient" do
      client.configure { |c| c.timeout = 120 }

      store_client = client.store

      expect(store_client.configuration.timeout).to eq(120)
    end
  end

  # Test convenience methods - they should delegate to the appropriate client
  describe "convenience methods" do
    let(:mock_pet) { double("Pet") }
    let(:mock_order) { double("Order") }

    describe "#create_pet" do
      it "delegates to pets.create_pet" do
        pet_data = { name: "Fido", photo_urls: ["url"] }

        expect(client.pets).to receive(:create_pet).with(pet_data).and_return(mock_pet)

        result = client.create_pet(pet_data)
        expect(result).to be(mock_pet)
      end
    end

    describe "#get_pet" do
      it "delegates to pets.get_pet" do
        expect(client.pets).to receive(:get_pet).with(123).and_return(mock_pet)

        result = client.get_pet(123)
        expect(result).to be(mock_pet)
      end
    end

    describe "#update_pet" do
      it "delegates to pets.update_pet" do
        pet_data = { id: 123, name: "Updated", photo_urls: ["url"] }

        expect(client.pets).to receive(:update_pet).with(pet_data).and_return(mock_pet)

        result = client.update_pet(pet_data)
        expect(result).to be(mock_pet)
      end
    end

    describe "#delete_pet" do
      it "delegates to pets.delete_pet" do
        expect(client.pets).to receive(:delete_pet).with(456).and_return(true)

        result = client.delete_pet(456)
        expect(result).to be true
      end
    end

    describe "#create_order" do
      it "delegates to store.create_order" do
        order_data = { pet_id: 123, quantity: 1 }

        expect(client.store).to receive(:create_order).with(order_data).and_return(mock_order)

        result = client.create_order(order_data)
        expect(result).to be(mock_order)
      end
    end

    describe "#get_order" do
      it "delegates to store.get_order" do
        expect(client.store).to receive(:get_order).with(789).and_return(mock_order)

        result = client.get_order(789)
        expect(result).to be(mock_order)
      end
    end

    describe "#delete_order" do
      it "delegates to store.delete_order" do
        expect(client.store).to receive(:delete_order).with(999).and_return(true)

        result = client.delete_order(999)
        expect(result).to be true
      end
    end
  end

  # Edge cases
  describe "edge cases" do
    it "handles multiple configure calls" do
      client.configure { |c| c.timeout = 30 }
      client.configure { |c| c.open_timeout = 5 }
      client.configure { |c| c.api_key = "key123" }

      expect(client.configuration.timeout).to eq(30)
      expect(client.configuration.open_timeout).to eq(5)
      expect(client.configuration.api_key).to eq("key123")
    end

    it "doesn't break if configure is called without block" do
      expect { client.configure }.not_to raise_error
    end
  end
end
