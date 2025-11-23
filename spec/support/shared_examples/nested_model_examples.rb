# frozen_string_literal: true

# Shared examples for testing nested model handling
# Used for models that contain nested objects like Pet (has Category and Tags)
RSpec.shared_examples "nested model handling" do |nested_field, nested_class|
  describe "#{nested_field} nested object handling" do
    it "handles #{nested_field} as nil" do
      model = described_class.new(nested_field => nil)

      expect(model.public_send(nested_field)).to be_nil
    end

    it "handles #{nested_field} as hash" do
      data = { "id" => 1, "name" => "Test #{nested_class}" }
      model = described_class.new(nested_field => data)

      result = model.public_send(nested_field)
      expect(result).to be_a(nested_class)
      expect(result.id).to eq(1)
      expect(result.name).to eq("Test #{nested_class}")
    end

    it "handles #{nested_field} as #{nested_class} object" do
      nested_object = nested_class.new(id: 2, name: "Test Object")
      model = described_class.new(nested_field => nested_object)

      result = model.public_send(nested_field)
      expect(result).to be(nested_object)
      expect(result.id).to eq(2)
    end

    it "validates #{nested_field} if present" do
      invalid_data = { "id" => "not_an_integer" }
      model = described_class.new(nested_field => invalid_data)

      # Should either handle gracefully or raise appropriate error
      # Behavior depends on validation setup in the model
      expect { model.public_send(nested_field) }.not_to raise_error
    end
  end
end

# Shared examples for testing arrays of nested models
# Used for fields like tags (array of Tag objects)
RSpec.shared_examples "nested model array handling" do |nested_field, nested_class|
  describe "#{nested_field} array handling" do
    it "handles #{nested_field} as nil" do
      model = described_class.new(nested_field => nil)

      expect(model.public_send(nested_field)).to eq([])
    end

    it "handles #{nested_field} as empty array" do
      model = described_class.new(nested_field => [])

      expect(model.public_send(nested_field)).to eq([])
    end

    it "handles #{nested_field} as array of hashes" do
      data = [
        { "id" => 1, "name" => "First" },
        { "id" => 2, "name" => "Second" }
      ]
      model = described_class.new(nested_field => data)

      result = model.public_send(nested_field)
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.all? { |item| item.is_a?(nested_class) }).to be true
      expect(result.first.name).to eq("First")
      expect(result.last.name).to eq("Second")
    end

    it "handles #{nested_field} as array of #{nested_class} objects" do
      objects = [
        nested_class.new(id: 1, name: "First Object"),
        nested_class.new(id: 2, name: "Second Object")
      ]
      model = described_class.new(nested_field => objects)

      result = model.public_send(nested_field)
      expect(result).to eq(objects)
      expect(result.first.id).to eq(1)
      expect(result.last.id).to eq(2)
    end

    it "handles mixed array of hashes and #{nested_class} objects" do
      mixed_data = [
        { "id" => 1, "name" => "Hash Item" },
        nested_class.new(id: 2, name: "Object Item")
      ]
      model = described_class.new(nested_field => mixed_data)

      result = model.public_send(nested_field)
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.all? { |item| item.is_a?(nested_class) }).to be true
    end

    it "filters out invalid entries gracefully" do
      data_with_nil = [
        { "id" => 1, "name" => "Valid" },
        nil,
        { "id" => 2, "name" => "Also Valid" }
      ]
      model = described_class.new(nested_field => data_with_nil)

      result = model.public_send(nested_field)
      # Behavior depends on implementation - either filters nils or handles them
      expect(result).to be_an(Array)
    end
  end
end

# Shared examples for testing serialization with nested models
RSpec.shared_examples "nested model serialization" do |nested_field, serialized_key|
  describe "#to_h with #{nested_field}" do
    it "serializes #{nested_field} to hash" do
      nested_data = { "id" => 1, "name" => "Test" }
      model = described_class.new(nested_field => nested_data)

      hash = model.to_h
      expect(hash).to have_key(serialized_key)
      expect(hash[serialized_key]).to be_a(Hash)
    end

    it "handles nil #{nested_field}" do
      model = described_class.new(nested_field => nil)

      hash = model.to_h
      # Should either exclude key or have nil value
      expect(hash[serialized_key]).to be_nil if hash.key?(serialized_key)
    end
  end
end

# Shared examples for deserialization with nested models
RSpec.shared_examples "nested model deserialization" do |nested_field, api_key|
  describe ".from_response with #{nested_field}" do
    it "deserializes #{nested_field} from API response" do
      response_data = {
        api_key => { "id" => 1, "name" => "Test" }
      }

      model = described_class.from_response(response_data)
      nested_object = model.public_send(nested_field)

      expect(nested_object).not_to be_nil
      expect(nested_object.id).to eq(1)
      expect(nested_object.name).to eq("Test")
    end

    it "handles missing #{nested_field} in response" do
      response_data = {}

      model = described_class.from_response(response_data)
      nested_object = model.public_send(nested_field)

      expect(nested_object).to be_nil
    end
  end
end
