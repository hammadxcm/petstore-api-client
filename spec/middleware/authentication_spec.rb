# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Middleware::Authentication do
  let(:app) { double("App", call: double("Response")) }
  let(:env) { double("Faraday::Env", request_headers: {}) }

  describe "#initialize" do
    it "accepts an authenticator option" do
      authenticator = PetstoreApiClient::Authentication::ApiKey.new("test-key")
      middleware = described_class.new(app, authenticator: authenticator)

      expect(middleware).to be_a(described_class)
    end

    it "works without an authenticator" do
      middleware = described_class.new(app)

      expect(middleware).to be_a(described_class)
    end
  end

  describe "#call" do
    context "with API key authentication" do
      let(:authenticator) { PetstoreApiClient::Authentication::ApiKey.new("special-key") }
      let(:middleware) { described_class.new(app, authenticator: authenticator) }

      before do
        # Mock HTTPS URL to avoid security warnings
        allow(env).to receive(:url).and_return(double(scheme: "https"))
      end

      it "applies authentication to request" do
        middleware.call(env)

        expect(env.request_headers["api_key"]).to eq("special-key")
      end

      it "calls the next middleware" do
        expect(app).to receive(:call).with(env)

        middleware.call(env)
      end

      it "returns the response from next middleware" do
        response = double("Response")
        allow(app).to receive(:call).and_return(response)

        result = middleware.call(env)
        expect(result).to eq(response)
      end
    end

    context "with no authentication (None strategy)" do
      let(:authenticator) { PetstoreApiClient::Authentication::None.new }
      let(:middleware) { described_class.new(app, authenticator: authenticator) }

      it "doesn't modify request headers" do
        middleware.call(env)

        expect(env.request_headers).to be_empty
      end

      it "still calls the next middleware" do
        expect(app).to receive(:call).with(env)

        middleware.call(env)
      end
    end

    context "without authenticator" do
      let(:middleware) { described_class.new(app) }

      it "doesn't crash when no authenticator is provided" do
        expect { middleware.call(env) }.not_to raise_error
      end

      it "calls the next middleware" do
        expect(app).to receive(:call).with(env)

        middleware.call(env)
      end
    end

    context "with unconfigured authenticator" do
      let(:authenticator) { PetstoreApiClient::Authentication::ApiKey.new(nil) }
      let(:middleware) { described_class.new(app, authenticator: authenticator) }

      it "doesn't apply authentication" do
        middleware.call(env)

        expect(env.request_headers).to be_empty
      end

      it "still calls the next middleware" do
        expect(app).to receive(:call).with(env)

        middleware.call(env)
      end
    end
  end

  describe "integration with Faraday" do
    it "can be added to Faraday middleware stack" do
      authenticator = PetstoreApiClient::Authentication::ApiKey.new("test-key")

      conn = Faraday.new do |f|
        f.use described_class, authenticator: authenticator
        f.adapter :test do |stub|
          stub.get("/test") { |_env| [200, {}, "OK"] }
        end
      end

      expect(conn.builder.handlers).to include(described_class)
    end

    it "applies authentication to actual request" do
      authenticator = PetstoreApiClient::Authentication::ApiKey.new("test-key")
      received_headers = nil

      conn = Faraday.new do |f|
        f.use described_class, authenticator: authenticator
        f.adapter :test do |stub|
          stub.get("/test") do |env|
            received_headers = env.request_headers
            [200, {}, "OK"]
          end
        end
      end

      conn.get("/test")

      expect(received_headers["api_key"]).to eq("test-key")
    end
  end
end
