# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Response do
  let(:faraday_response) { double("Faraday::Response") }

  describe "#initialize" do
    it "wraps a Faraday response" do
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return({ "id" => 123 })
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.status).to eq(200)
      expect(response.body).to eq({ "id" => 123 })
    end

    it "handles nil body" do
      allow(faraday_response).to receive(:status).and_return(204)
      allow(faraday_response).to receive(:body).and_return(nil)
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.body).to eq({})
    end

    it "handles empty string body" do
      allow(faraday_response).to receive(:status).and_return(204)
      allow(faraday_response).to receive(:body).and_return("")
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.body).to eq({})
    end
  end

  describe "#success?" do
    it "returns true for 2xx status codes" do
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return({})
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.success?).to be true
    end

    it "returns false for 4xx status codes" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return({})
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.success?).to be false
    end
  end

  describe "#error?" do
    it "returns false for successful responses" do
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return({})
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error?).to be false
    end

    it "returns true for error responses" do
      allow(faraday_response).to receive(:status).and_return(500)
      allow(faraday_response).to receive(:body).and_return({})
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error?).to be true
    end
  end

  describe "#error_message" do
    it "extracts message from hash body with string key" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return({ "message" => "Not found" })
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_message).to eq("Not found")
    end

    it "extracts message from hash body with symbol key" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return({ message: "Not found" })
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_message).to eq("Not found")
    end

    it "returns default message for hash without message key" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return({ "error" => "something" })
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_message).to eq("Unknown error")
    end

    it "handles HTML error responses" do
      allow(faraday_response).to receive(:status).and_return(500)
      allow(faraday_response).to receive(:body).and_return("<html><body>Error</body></html>")
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_message).to eq("Request failed with status 500")
    end

    it "handles plain text error responses" do
      allow(faraday_response).to receive(:status).and_return(500)
      allow(faraday_response).to receive(:body).and_return("Internal server error")
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_message).to eq("Internal server error")
    end

    it "returns nil for successful responses" do
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return({})
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_message).to be_nil
    end
  end

  describe "#error_code" do
    it "extracts code from hash body" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return({ "code" => 404 })
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_code).to eq(404)
    end

    it "returns status code if body is not a hash" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return("Not found")
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_code).to eq(404)
    end
  end

  describe "#error_type" do
    it "extracts type from hash body" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return({ "type" => "NotFound" })
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_type).to eq("NotFound")
    end

    it "returns nil if body is not a hash" do
      allow(faraday_response).to receive(:status).and_return(404)
      allow(faraday_response).to receive(:body).and_return("Not found")
      allow(faraday_response).to receive(:headers).and_return({})

      response = described_class.new(faraday_response)
      expect(response.error_type).to be_nil
    end
  end
end
