# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Request do
  # Create a test class that includes both Connection and Request modules
  let(:test_class) do
    Class.new do
      include PetstoreApiClient::Connection
      include PetstoreApiClient::Request

      attr_reader :configuration

      def initialize(config)
        @configuration = config
      end
    end
  end

  let(:config) { PetstoreApiClient::Configuration.new }
  let(:client) { test_class.new(config) }
  let(:mock_response) { double("Faraday::Response", status: 200, body: { "id" => 123 }, headers: {}) }

  describe "#get" do
    it "performs a GET request" do
      connection = client.send(:connection)
      expect(connection).to receive(:get).and_yield(double.as_null_object).and_return(mock_response)

      client.send(:get, "test/path")
    end

    it "passes params to the request" do
      request_stub = double
      expect(request_stub).to receive(:url).with("test/path")
      expect(request_stub).to receive(:params=).with({ status: "available" })

      connection = client.send(:connection)
      expect(connection).to receive(:get).and_yield(request_stub).and_return(mock_response)

      client.send(:get, "test/path", params: { status: "available" })
    end

    it "returns a Response object" do
      allow(client.send(:connection)).to receive(:get).and_return(mock_response)

      result = client.send(:get, "test/path")

      expect(result).to be_a(PetstoreApiClient::Response)
      expect(result.status).to eq(200)
    end
  end

  describe "#post" do
    it "performs a POST request" do
      connection = client.send(:connection)
      expect(connection).to receive(:post).and_yield(double.as_null_object).and_return(mock_response)

      client.send(:post, "test/path")
    end

    it "passes body to the request" do
      request_stub = double
      expect(request_stub).to receive(:url).with("test/path")
      expect(request_stub).to receive(:body=).with({ name: "Test" })

      connection = client.send(:connection)
      expect(connection).to receive(:post).and_yield(request_stub).and_return(mock_response)

      client.send(:post, "test/path", body: { name: "Test" })
    end

    it "returns a Response object" do
      allow(client.send(:connection)).to receive(:post).and_return(mock_response)

      result = client.send(:post, "test/path", body: {})

      expect(result).to be_a(PetstoreApiClient::Response)
    end
  end

  describe "#put" do
    it "performs a PUT request" do
      connection = client.send(:connection)
      expect(connection).to receive(:put).and_yield(double.as_null_object).and_return(mock_response)

      client.send(:put, "test/path")
    end

    it "passes body to the request" do
      request_stub = double
      expect(request_stub).to receive(:url).with("test/path")
      expect(request_stub).to receive(:body=).with({ name: "Updated" })

      connection = client.send(:connection)
      expect(connection).to receive(:put).and_yield(request_stub).and_return(mock_response)

      client.send(:put, "test/path", body: { name: "Updated" })
    end
  end

  describe "#delete" do
    it "performs a DELETE request" do
      connection = client.send(:connection)
      expect(connection).to receive(:delete).and_yield(double.as_null_object).and_return(mock_response)

      client.send(:delete, "test/path")
    end

    it "passes params to the request" do
      request_stub = double
      expect(request_stub).to receive(:url).with("test/path")
      expect(request_stub).to receive(:params=).with({ api_key: "key" })

      connection = client.send(:connection)
      expect(connection).to receive(:delete).and_yield(request_stub).and_return(mock_response)

      client.send(:delete, "test/path", params: { api_key: "key" })
    end
  end

  describe "error handling" do
    context "when response is an error" do
      let(:error_response) { double("Faraday::Response", status: 404, body: { "message" => "Not found" }, headers: {}) }

      it "raises NotFoundError for 404 status" do
        allow(client.send(:connection)).to receive(:get).and_return(error_response)

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::NotFoundError, /Not found/)
      end
    end

    context "when response is 400" do
      let(:bad_request_response) { double("Faraday::Response", status: 400, body: { "message" => "Bad request", "type" => "InvalidOrder" }, headers: {}) }

      it "raises InvalidOrderError for order-related errors" do
        allow(client.send(:connection)).to receive(:post).and_return(bad_request_response)

        expect do
          client.send(:post, "store/order", body: {})
        end.to raise_error(PetstoreApiClient::InvalidOrderError, /Bad request/)
      end

      it "raises InvalidInputError for other 400 errors" do
        generic_bad_request = double("Faraday::Response", status: 400, body: { "message" => "Bad data" }, headers: {})
        allow(client.send(:connection)).to receive(:post).and_return(generic_bad_request)

        expect do
          client.send(:post, "test/path", body: {})
        end.to raise_error(PetstoreApiClient::InvalidInputError)
      end
    end

    context "when response is 405" do
      let(:method_not_allowed) { double("Faraday::Response", status: 405, body: { "message" => "Method not allowed" }, headers: {}) }

      it "raises InvalidInputError" do
        allow(client.send(:connection)).to receive(:get).and_return(method_not_allowed)

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::InvalidInputError)
      end
    end

    context "when response is 429 (rate limit)" do
      let(:rate_limit_response) do
        double("Faraday::Response",
               status: 429,
               body: { "message" => "Too many requests" },
               headers: { "Retry-After" => "60" })
      end

      it "raises RateLimitError" do
        allow(client.send(:connection)).to receive(:get).and_return(rate_limit_response)

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::RateLimitError, /Too many requests/)
      end

      it "includes retry_after from response header" do
        allow(client.send(:connection)).to receive(:get).and_return(rate_limit_response)

        begin
          client.send(:get, "test/path")
        rescue PetstoreApiClient::RateLimitError => e
          expect(e.retry_after).to eq("60")
        end
      end

      it "handles lowercase retry-after header" do
        response_lowercase = double("Faraday::Response",
                                    status: 429,
                                    body: { "message" => "Rate limited" },
                                    headers: { "retry-after" => "30" })
        allow(client.send(:connection)).to receive(:get).and_return(response_lowercase)

        begin
          client.send(:get, "test/path")
        rescue PetstoreApiClient::RateLimitError => e
          expect(e.retry_after).to eq("30")
        end
      end
    end

    context "when response is a server error" do
      let(:server_error) { double("Faraday::Response", status: 500, body: { "message" => "Internal server error" }, headers: {}) }

      it "raises ApiError" do
        allow(client.send(:connection)).to receive(:get).and_return(server_error)

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::ApiError, /Internal server error/)
      end
    end

    context "when network error occurs" do
      it "raises ConnectionError for connection failures" do
        allow(client.send(:connection)).to receive(:get).and_raise(Faraday::ConnectionFailed,
                                                                   "Failed to open TCP connection")

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::ConnectionError, /Connection failed/)
      end

      it "raises ConnectionError for timeouts" do
        allow(client.send(:connection)).to receive(:get).and_raise(Faraday::TimeoutError, "execution expired")

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::ConnectionError, /Request timeout/)
      end
    end

    context "when custom PetstoreApiClient error is raised" do
      it "doesn't double-wrap errors" do
        allow(client.send(:connection)).to receive(:get).and_raise(PetstoreApiClient::NotFoundError, "Already wrapped")

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::NotFoundError, "Already wrapped")
      end
    end

    context "when unexpected error occurs" do
      it "wraps StandardError as ApiError" do
        allow(client.send(:connection)).to receive(:get).and_raise(StandardError, "Something weird happened")

        expect do
          client.send(:get, "test/path")
        end.to raise_error(PetstoreApiClient::ApiError, /Request failed: Something weird happened/)
      end
    end
  end

  describe "private #request method" do
    it "doesn't set params if none provided" do
      request_stub = double
      expect(request_stub).to receive(:url).with("path")
      expect(request_stub).not_to receive(:params=)
      expect(request_stub).not_to receive(:body=)

      allow(client.send(:connection)).to receive(:get).and_yield(request_stub).and_return(mock_response)

      client.send(:get, "path")
    end

    it "doesn't set body if none provided" do
      request_stub = double
      expect(request_stub).to receive(:url).with("path")
      expect(request_stub).not_to receive(:params=)
      expect(request_stub).not_to receive(:body=)

      allow(client.send(:connection)).to receive(:post).and_yield(request_stub).and_return(mock_response)

      client.send(:post, "path")
    end
  end
end
