# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Error Classes" do
  describe PetstoreApiClient::Error do
    it "stores status_code and error_type" do
      error = described_class.new("Test error", status_code: 500, error_type: "ServerError")
      expect(error.status_code).to eq(500)
      expect(error.error_type).to eq("ServerError")
      expect(error.message).to eq("Test error")
    end
  end

  describe PetstoreApiClient::ValidationError do
    it "inherits from Error" do
      expect(described_class).to be < PetstoreApiClient::Error
    end
  end

  describe PetstoreApiClient::NotFoundError do
    it "sets status code to 404" do
      error = described_class.new
      expect(error.status_code).to eq(404)
      expect(error.error_type).to eq("NotFound")
    end

    it "allows custom message" do
      error = described_class.new("Pet not found")
      expect(error.message).to eq("Pet not found")
    end
  end

  describe PetstoreApiClient::InvalidInputError do
    it "sets status code to 405" do
      error = described_class.new
      expect(error.status_code).to eq(405)
    end
  end

  describe PetstoreApiClient::InvalidOrderError do
    it "sets status code to 400" do
      error = described_class.new
      expect(error.status_code).to eq(400)
    end
  end

  describe PetstoreApiClient::ConnectionError do
    it "has nil status code" do
      error = described_class.new
      expect(error.status_code).to be_nil
      expect(error.error_type).to eq("Connection")
    end
  end

  describe PetstoreApiClient::RateLimitError do
    it "sets status code to 429" do
      error = described_class.new
      expect(error.status_code).to eq(429)
      expect(error.error_type).to eq("RateLimit")
    end

    it "stores retry_after header value" do
      error = described_class.new("Too many requests", retry_after: "60")
      expect(error.retry_after).to eq("60")
      expect(error.message).to eq("Too many requests")
    end

    it "handles nil retry_after" do
      error = described_class.new
      expect(error.retry_after).to be_nil
    end
  end

  describe PetstoreApiClient::ApiError do
    it "inherits from Error" do
      expect(described_class).to be < PetstoreApiClient::Error
    end
  end
end
