# frozen_string_literal: true

# Shared examples for testing ResourceOperations concern
# Used by both PetClient and StoreClient specs
RSpec.shared_examples "resource operations" do |resource_type|
  describe "#build_resource" do
    it "converts hash to #{resource_type} object" do
      data = build_valid_resource_data

      resource = client.send(:build_resource, data)

      expect(resource).to be_a(expected_model_class)
    end

    it "returns #{resource_type} object unchanged if already a #{resource_type}" do
      original = expected_model_class.new(build_valid_resource_data)

      result = client.send(:build_resource, original)

      expect(result).to be(original)
    end
  end

  describe "#validate_resource!" do
    it "raises error if #{resource_type} is invalid" do
      invalid_resource = build_invalid_resource

      expect do
        client.send(:validate_resource!, invalid_resource)
      end.to raise_error(PetstoreApiClient::ValidationError, /Invalid #{resource_type} data/)
    end

    it "does not raise error for valid #{resource_type}" do
      valid_resource = build_valid_resource

      expect do
        client.send(:validate_resource!, valid_resource)
      end.not_to raise_error
    end
  end

  describe "#validate_id!" do
    it "accepts integer IDs" do
      expect do
        client.send(:validate_id!, 123, "#{resource_type} ID")
      end.not_to raise_error
    end

    it "accepts numeric string IDs" do
      expect do
        client.send(:validate_id!, "456", "#{resource_type} ID")
      end.not_to raise_error
    end

    it "rejects non-numeric string IDs" do
      expect do
        client.send(:validate_id!, "abc", "#{resource_type} ID")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "rejects nil" do
      expect do
        client.send(:validate_id!, nil, "#{resource_type} ID")
      end.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    it "uses custom field name in error message" do
      expect do
        client.send(:validate_id!, nil, "Custom ID")
      end.to raise_error(PetstoreApiClient::ValidationError, /Custom ID can't be nil/)
    end
  end

  describe "#model_class" do
    it "returns the correct model class" do
      expect(client.send(:model_class)).to eq(expected_model_class)
    end
  end

  describe "#resource_name" do
    it "returns the correct resource name" do
      expect(client.send(:resource_name)).to eq(expected_resource_name)
    end
  end

  describe "#id_field_name" do
    it "returns the correct ID field name" do
      expect(client.send(:id_field_name)).to eq(expected_id_field_name)
    end
  end
end

# Shared examples for delete operations
RSpec.shared_examples "delete resource operation" do |resource_type, delete_method|
  describe "##{delete_method}" do
    let(:resource_id) { 789 }
    let(:delete_response) { build_delete_response(message: "#{resource_type} deleted") }

    it "validates resource ID is present" do
      expect do
        client.public_send(delete_method, nil)
      end.to raise_error(PetstoreApiClient::ValidationError, /can't be nil/)
    end

    it "validates resource ID is an integer" do
      expect do
        client.public_send(delete_method, "not_a_number")
      end.to raise_error(PetstoreApiClient::ValidationError, /must be an integer/)
    end

    it "calls delete endpoint with correct path" do
      expect(client).to receive(:delete).with("#{resource_type.downcase}/#{resource_id}").and_return(delete_response)
      client.public_send(delete_method, resource_id)
    end

    it "returns the response body" do
      allow(client).to receive(:delete).and_return(delete_response)
      result = client.public_send(delete_method, resource_id)

      expect(result).to eq(delete_response.body)
    end

    it "handles API errors" do
      error_response = build_error_response(status: 404, message: "#{resource_type} not found")
      allow(client).to receive(:delete).and_raise(PetstoreApiClient::NotFoundError, error_response.body["message"])

      expect do
        client.public_send(delete_method, resource_id)
      end.to raise_error(PetstoreApiClient::NotFoundError, /not found/)
    end
  end
end

# Shared examples for update/replace operations
RSpec.shared_examples "update resource operation" do |resource_type, update_method|
  describe "##{update_method}" do
    let(:resource_data) { build_valid_resource_data }
    let(:update_response) { build_mock_response(body: resource_data.merge("id" => 123)) }

    it "validates resource data" do
      invalid_resource = build_invalid_resource

      expect do
        client.public_send(update_method, invalid_resource)
      end.to raise_error(PetstoreApiClient::ValidationError, /Invalid #{resource_type}/)
    end

    it "builds resource from hash" do
      allow(client).to receive(:put).and_return(update_response)

      result = client.public_send(update_method, resource_data)

      expect(result).to be_a(expected_model_class)
    end

    it "accepts resource object directly" do
      resource_object = expected_model_class.new(resource_data)
      allow(client).to receive(:put).and_return(update_response)

      result = client.public_send(update_method, resource_object)

      expect(result).to be_a(expected_model_class)
    end

    it "calls put endpoint with correct data" do
      expect(client).to receive(:put).and_return(update_response)
      client.public_send(update_method, resource_data)
    end

    it "returns updated resource" do
      allow(client).to receive(:put).and_return(update_response)

      result = client.public_send(update_method, resource_data)

      expect(result.id).to eq(123)
    end
  end
end
