# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Clients::PetClient do
  let(:config) { PetstoreApiClient::Configuration.new }
  let(:client) { described_class.new(config) }

  # Mock the response object
  let(:mock_response) do
    double("Response", body: { "id" => 123, "name" => "Fido", "photoUrls" => ["url"], "status" => "available" })
  end

  describe "#create_pet" do
    it "validates pet data before making request" do
      invalid_data = { name: "Test" } # Missing photo_urls

      expect do
        client.create_pet(invalid_data)
      end.to raise_error(PetstoreApiClient::ValidationError, /Photo urls/)
    end

    it "builds pet from hash and calls post endpoint" do
      pet_data = { name: "Fido", photo_urls: ["url"], status: "available" }

      allow(client).to receive(:post).with("pet", body: anything).and_return(mock_response)

      result = client.create_pet(pet_data)

      expect(result).to be_a(PetstoreApiClient::Models::Pet)
      expect(result.name).to eq("Fido")
    end

    it "accepts a Pet object directly" do
      pet = PetstoreApiClient::Models::Pet.new(name: "Buddy", photo_urls: ["url"])

      allow(client).to receive(:post).and_return(mock_response)

      result = client.create_pet(pet)
      expect(result).to be_a(PetstoreApiClient::Models::Pet)
    end

    it "properly converts pet to API format with camelCase" do
      pet_data = { name: "Test", photo_urls: %w[url1 url2], status: "pending" }

      # Capture what gets passed to post
      expect(client).to receive(:post) do |_path, body:|
        expect(body[:photoUrls]).to eq(%w[url1 url2])
        expect(body[:name]).to eq("Test")
        expect(body[:status]).to eq("pending")
        mock_response
      end

      client.create_pet(pet_data)
    end
  end

  describe "#update_pet" do
    it "validates pet data before making request" do
      invalid_data = { id: 123, name: "" } # Empty name, missing photo_urls

      expect do
        client.update_pet(invalid_data)
      end.to raise_error(PetstoreApiClient::ValidationError)
    end

    it "calls put endpoint with pet data" do
      pet_data = { id: 123, name: "Updated", photo_urls: ["url"] }

      allow(client).to receive(:put).with("pet", body: anything).and_return(mock_response)

      result = client.update_pet(pet_data)
      expect(result).to be_a(PetstoreApiClient::Models::Pet)
    end

    it "handles nested category and tags" do
      pet_data = {
        id: 123,
        name: "Test",
        photo_urls: ["url"],
        category: { id: 1, name: "Dogs" },
        tags: [{ id: 1, name: "friendly" }]
      }

      expect(client).to receive(:put) do |_path, body:|
        expect(body[:category]).to eq({ id: 1, name: "Dogs" })
        expect(body[:tags]).to eq([{ id: 1, name: "friendly" }])
        mock_response
      end

      client.update_pet(pet_data)
    end
  end

  describe "#get_pet" do
    it "validates pet_id is an integer" do
      expect do
        client.get_pet("not_a_number")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "validates pet_id is not nil" do
      expect do
        client.get_pet(nil)
      end.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    it "accepts string numeric IDs" do
      # This was tricky - turns out we support string IDs if they're numeric
      allow(client).to receive(:get).with("pet/123").and_return(mock_response)

      result = client.get_pet("123")
      expect(result).to be_a(PetstoreApiClient::Models::Pet)
    end

    it "calls get endpoint with correct path" do
      expect(client).to receive(:get).with("pet/456").and_return(mock_response)

      client.get_pet(456)
    end

    it "returns a Pet object from response" do
      allow(client).to receive(:get).and_return(mock_response)

      result = client.get_pet(123)

      expect(result).to be_a(PetstoreApiClient::Models::Pet)
      expect(result.id).to eq(123)
      expect(result.name).to eq("Fido")
    end
  end

  describe "#delete_pet" do
    let(:delete_response) { double("Response", body: { "message" => "Pet deleted" }) }

    it "validates pet_id is present" do
      expect { client.delete_pet(nil) }.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    it "validates pet_id is numeric" do
      expect do
        client.delete_pet("abc")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "calls delete endpoint with correct path" do
      expect(client).to receive(:delete).with("pet/789").and_return(delete_response)

      client.delete_pet(789)
    end

    it "returns true on successful deletion" do
      allow(client).to receive(:delete).and_return(delete_response)

      result = client.delete_pet(123)
      expect(result).to be true
    end
  end

  describe "#find_by_status" do
    let(:available_pets_data) do
      [
        { "id" => 1, "name" => "Pet1", "photoUrls" => ["url1"], "status" => "available" },
        { "id" => 2, "name" => "Pet2", "photoUrls" => ["url2"], "status" => "available" },
        { "id" => 3, "name" => "Pet3", "photoUrls" => ["url3"], "status" => "available" }
      ]
    end
    let(:find_response) { double("Response", body: available_pets_data) }

    it "finds pets by status" do
      allow(client).to receive(:get).with("pet/findByStatus", params: { status: "available" }).and_return(find_response)

      result = client.find_by_status("available")

      expect(result).to be_a(PetstoreApiClient::PaginatedCollection)
      expect(result.count).to eq(3)
      expect(result.first).to be_a(PetstoreApiClient::Models::Pet)
      expect(result.first.name).to eq("Pet1")
    end

    it "validates status values" do
      expect do
        client.find_by_status("invalid_status")
      end.to raise_error(PetstoreApiClient::ValidationError, /Invalid status value/)
    end

    it "accepts multiple statuses" do
      allow(client).to receive(:get).with("pet/findByStatus",
                                          params: { status: "available,pending" }).and_return(find_response)

      result = client.find_by_status(%w[available pending])

      expect(result).to be_a(PetstoreApiClient::PaginatedCollection)
    end

    it "applies pagination to results" do
      allow(client).to receive(:get).and_return(find_response)

      result = client.find_by_status("available", page: 1, per_page: 2)

      expect(result.count).to eq(2) # Only first 2 items
      expect(result.page).to eq(1)
      expect(result.per_page).to eq(2)
      expect(result.total_count).to eq(3)
    end

    it "returns second page when requested" do
      allow(client).to receive(:get).and_return(find_response)

      result = client.find_by_status("available", page: 2, per_page: 2)

      expect(result.count).to eq(1) # Only last item
      expect(result.first.name).to eq("Pet3")
      expect(result.page).to eq(2)
    end

    it "supports offset/limit pagination style" do
      allow(client).to receive(:get).and_return(find_response)

      result = client.find_by_status("available", offset: 1, limit: 1)

      expect(result.count).to eq(1)
      expect(result.first.name).to eq("Pet2") # Second item (offset 1)
    end
  end

  describe "#find_by_tags" do
    let(:tagged_pets_data) do
      [
        { "id" => 10, "name" => "TaggedPet1", "photoUrls" => ["url"], "tags" => [{ "name" => "friendly" }] },
        { "id" => 11, "name" => "TaggedPet2", "photoUrls" => ["url"], "tags" => [{ "name" => "friendly" }] }
      ]
    end
    let(:find_response) { double("Response", body: tagged_pets_data) }

    it "finds pets by tags" do
      allow(client).to receive(:get).with("pet/findByTags", params: { tags: "friendly" }).and_return(find_response)

      result = client.find_by_tags("friendly")

      expect(result).to be_a(PetstoreApiClient::PaginatedCollection)
      expect(result.count).to eq(2)
      expect(result.first).to be_a(PetstoreApiClient::Models::Pet)
    end

    it "accepts multiple tags" do
      allow(client).to receive(:get).with("pet/findByTags",
                                          params: { tags: "friendly,vaccinated" }).and_return(find_response)

      result = client.find_by_tags(%w[friendly vaccinated])

      expect(result).to be_a(PetstoreApiClient::PaginatedCollection)
    end

    it "raises error for empty tags" do
      expect do
        client.find_by_tags([])
      end.to raise_error(PetstoreApiClient::ValidationError, /Tags cannot be empty/)
    end

    it "applies pagination to results" do
      allow(client).to receive(:get).and_return(find_response)

      result = client.find_by_tags("friendly", page: 1, per_page: 1)

      expect(result.count).to eq(1)
      expect(result.page).to eq(1)
      expect(result.total_count).to eq(2)
    end
  end

  # Test ResourceOperations concern methods
  describe "ResourceOperations concern" do
    # Helper methods for shared examples
    let(:expected_model_class) { PetstoreApiClient::Models::Pet }
    let(:expected_resource_name) { "pet" }
    let(:expected_id_field_name) { "Pet ID" }

    def build_valid_resource_data
      { name: "Test", photo_urls: ["url"] }
    end

    def build_valid_resource
      PetstoreApiClient::Models::Pet.new(name: "Test", photo_urls: ["url"])
    end

    def build_invalid_resource
      PetstoreApiClient::Models::Pet.new(name: "")
    end

    # Use shared examples from resource_operations_examples.rb
    it_behaves_like "resource operations", "pet"
  end
end
