# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pet Client Integration", :vcr do
  let(:client) { PetstoreApiClient::ApiClient.new }
  let(:pet_client) { client.pets }

  let(:valid_pet_data) do
    {
      id: 12_345_678,
      name: "FidoTestDog",
      photo_urls: ["https://example.com/photos/fido-1.jpg"],
      category: { id: 1, name: "Dogs" },
      tags: [{ id: 10, name: "friendly" }],
      status: "available"
    }
  end

  describe "#create_pet", vcr: { cassette_name: "pet_client/create_pet_success" } do
    it "creates a new pet successfully" do
      pet = pet_client.create_pet(valid_pet_data)

      expect(pet).to be_a(PetstoreApiClient::Models::Pet)
      expect(pet.name).to eq("FidoTestDog")
      expect(pet.status).to eq("available")
      expect(pet.photo_urls).to include("https://example.com/photos/fido-1.jpg")
    end
  end

  describe "#create_pet with invalid data", vcr: { cassette_name: "pet_client/create_pet_invalid" } do
    it "raises ValidationError for missing required fields" do
      expect do
        pet_client.create_pet(name: "NoPhotos")
      end.to raise_error(PetstoreApiClient::ValidationError, /Photo urls/)
    end
  end

  describe "#update_pet", vcr: { cassette_name: "pet_client/update_pet_success" } do
    it "updates an existing pet successfully" do
      # First create a pet
      pet_client.create_pet(valid_pet_data)

      # Then update it
      updated_data = valid_pet_data.merge(name: "FidoUpdated", status: "pending")
      updated_pet = pet_client.update_pet(updated_data)

      expect(updated_pet).to be_a(PetstoreApiClient::Models::Pet)
      expect(updated_pet.name).to eq("FidoUpdated")
      expect(updated_pet.status).to eq("pending")
    end
  end

  describe "#update_pet with non-existent pet" do
    it "raises NotFoundError for non-existent pet", vcr: { cassette_name: "pet_client/update_pet_not_found" } do
      non_existent_pet = valid_pet_data.merge(id: 999_999_999)

      expect do
        pet_client.update_pet(non_existent_pet)
      end.to raise_error(PetstoreApiClient::NotFoundError)
    end
  end

  describe "#get_pet", vcr: { cassette_name: "pet_client/get_pet_success" } do
    it "retrieves a pet by ID successfully" do
      # Create a pet first
      created_pet = pet_client.create_pet(valid_pet_data)

      # Retrieve it
      fetched_pet = pet_client.get_pet(created_pet.id)

      expect(fetched_pet).to be_a(PetstoreApiClient::Models::Pet)
      expect(fetched_pet.id).to eq(created_pet.id)
      expect(fetched_pet.name).to eq(created_pet.name)
    end
  end

  describe "#get_pet with non-existent ID" do
    it "raises NotFoundError", vcr: { cassette_name: "pet_client/get_pet_not_found" } do
      expect do
        pet_client.get_pet(999_999_999)
      end.to raise_error(PetstoreApiClient::NotFoundError)
    end
  end

  describe "#delete_pet", vcr: { cassette_name: "pet_client/delete_pet_success" } do
    it "deletes a pet successfully" do
      # Create a pet first
      created_pet = pet_client.create_pet(valid_pet_data)

      # Delete it
      result = pet_client.delete_pet(created_pet.id)

      expect(result).to be true
    end
  end

  describe "#delete_pet with non-existent ID" do
    it "raises NotFoundError", vcr: { cassette_name: "pet_client/delete_pet_not_found" } do
      expect do
        pet_client.delete_pet(999_999_999)
      end.to raise_error(PetstoreApiClient::NotFoundError)
    end
  end

  describe "validation before API call" do
    it "validates pet data before making the request" do
      invalid_pet = { name: "" } # Empty name, missing photo_urls

      expect do
        pet_client.create_pet(invalid_pet)
      end.to raise_error(PetstoreApiClient::ValidationError)
    end

    it "validates pet ID is an integer" do
      expect do
        pet_client.get_pet("not_a_number")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "validates pet ID is not nil" do
      expect { pet_client.delete_pet(nil) }.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    # TODO: Add test for very long pet names (> 1000 chars)
    # it "handles extremely long pet names gracefully" do
    #   # Need to figure out if API has a length limit
    # end
  end

  # Skipping for now - need to add findByStatus endpoint first
  xdescribe "#find_by_status" do
    it "finds pets by available status" do
      # Will implement when endpoint is added in v0.2.0
    end
  end
end
