# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Models::Pet do
  describe "validations" do
    it "is valid with required attributes" do
      pet = described_class.new(
        name: "Fido",
        photo_urls: ["http://example.com/photo.jpg"]
      )
      expect(pet).to be_valid
    end

    describe "name validation" do
      it "is invalid without a name" do
        pet = described_class.new(photo_urls: ["http://example.com/photo.jpg"])
        expect(pet).not_to be_valid
        expect(pet.errors[:name]).to include("can't be blank")
      end

      it "is invalid with an empty name" do
        pet = described_class.new(name: "", photo_urls: ["http://example.com/photo.jpg"])
        expect(pet).not_to be_valid
      end
    end

    describe "photo_urls validation" do
      it "is invalid without photo_urls" do
        pet = described_class.new(name: "Fido")
        expect(pet).not_to be_valid
        expect(pet.errors[:photo_urls]).to include("cannot be empty")
      end

      it "is invalid with empty photo_urls array" do
        pet = described_class.new(name: "Fido", photo_urls: [])
        expect(pet).not_to be_valid
        expect(pet.errors[:photo_urls]).to include("cannot be empty")
      end

      it "is invalid when photo_urls is not an array" do
        pet = described_class.new(name: "Fido", photo_urls: "not an array")
        expect(pet).not_to be_valid
        expect(pet.errors[:photo_urls]).to include("must be an array")
      end
    end

    describe "status validation" do
      it "is valid with 'available' status" do
        pet = described_class.new(name: "Fido", photo_urls: ["url"], status: "available")
        expect(pet).to be_valid
      end

      it "is valid with 'pending' status" do
        pet = described_class.new(name: "Fido", photo_urls: ["url"], status: "pending")
        expect(pet).to be_valid
      end

      it "is valid with 'sold' status" do
        pet = described_class.new(name: "Fido", photo_urls: ["url"], status: "sold")
        expect(pet).to be_valid
      end

      it "is valid with nil status" do
        pet = described_class.new(name: "Fido", photo_urls: ["url"], status: nil)
        expect(pet).to be_valid
      end

      it "is invalid with an invalid status" do
        pet = described_class.new(name: "Fido", photo_urls: ["url"], status: "invalid")
        expect(pet).not_to be_valid
        expect(pet.errors[:status].first).to match(/must be one of/)
      end
    end

    describe "nested category validation" do
      it "handles category as hash" do
        pet = described_class.new(
          name: "Fido",
          photo_urls: ["url"],
          category: { id: 1, name: "Dogs" }
        )
        expect(pet).to be_valid
        expect(pet.category).to be_a(PetstoreApiClient::Models::Category)
      end

      it "handles category as Category object" do
        category = PetstoreApiClient::Models::Category.new(id: 1, name: "Dogs")
        pet = described_class.new(
          name: "Fido",
          photo_urls: ["url"],
          category: category
        )
        expect(pet.category).to be_a(PetstoreApiClient::Models::Category)
      end
    end

    describe "nested tags validation" do
      it "handles tags as hashes" do
        pet = described_class.new(
          name: "Fido",
          photo_urls: ["url"],
          tags: [{ id: 1, name: "friendly" }]
        )
        expect(pet).to be_valid
        expect(pet.tags.first).to be_a(PetstoreApiClient::Models::Tag)
      end

      it "handles tags as Tag objects" do
        tag = PetstoreApiClient::Models::Tag.new(id: 1, name: "friendly")
        pet = described_class.new(
          name: "Fido",
          photo_urls: ["url"],
          tags: [tag]
        )
        expect(pet.tags.first).to be_a(PetstoreApiClient::Models::Tag)
      end

      it "handles empty tags array" do
        pet = described_class.new(
          name: "Fido",
          photo_urls: ["url"],
          tags: []
        )
        expect(pet.tags).to eq([])
        expect(pet).to be_valid
      end

      it "handles nil tags" do
        pet = described_class.new(
          name: "Fido",
          photo_urls: ["url"],
          tags: nil
        )
        expect(pet.tags).to be_nil
        expect(pet).to be_valid
      end
    end
  end

  describe "#to_h" do
    it "converts the pet to a hash" do
      pet = described_class.new(
        id: 123,
        name: "Fido",
        photo_urls: ["http://example.com/photo.jpg"],
        status: "available"
      )

      hash = pet.to_h
      expect(hash[:id]).to eq(123)
      expect(hash[:name]).to eq("Fido")
      expect(hash[:photoUrls]).to eq(["http://example.com/photo.jpg"])
      expect(hash[:status]).to eq("available")
    end

    it "includes category when present" do
      category = PetstoreApiClient::Models::Category.new(id: 1, name: "Dogs")
      pet = described_class.new(
        name: "Fido",
        photo_urls: ["url"],
        category: category
      )

      hash = pet.to_h
      expect(hash[:category]).to eq({ id: 1, name: "Dogs" })
    end

    it "includes tags when present" do
      tags = [
        PetstoreApiClient::Models::Tag.new(id: 1, name: "friendly"),
        PetstoreApiClient::Models::Tag.new(id: 2, name: "vaccinated")
      ]
      pet = described_class.new(
        name: "Fido",
        photo_urls: ["url"],
        tags: tags
      )

      hash = pet.to_h
      expect(hash[:tags]).to eq([
                                  { id: 1, name: "friendly" },
                                  { id: 2, name: "vaccinated" }
                                ])
    end
  end

  describe ".from_response" do
    it "creates a Pet from API response data" do
      data = {
        "id" => 123,
        "name" => "Fido",
        "photoUrls" => ["http://example.com/photo.jpg"],
        "status" => "available",
        "category" => { "id" => 1, "name" => "Dogs" },
        "tags" => [{ "id" => 1, "name" => "friendly" }]
      }

      pet = described_class.from_response(data)
      expect(pet.id).to eq(123)
      expect(pet.name).to eq("Fido")
      expect(pet.photo_urls).to eq(["http://example.com/photo.jpg"])
      expect(pet.status).to eq("available")
      expect(pet.category).to be_a(PetstoreApiClient::Models::Category)
      expect(pet.category.name).to eq("Dogs")
      expect(pet.tags.first).to be_a(PetstoreApiClient::Models::Tag)
    end

    it "returns nil for nil data" do
      expect(described_class.from_response(nil)).to be_nil
    end
  end
end
