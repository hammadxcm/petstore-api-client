# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Authentication::ApiKey do
  describe "#initialize" do
    it "accepts an API key" do
      auth = described_class.new("special-key")
      expect(auth.api_key).to eq("special-key")
    end

    it "strips whitespace from API key" do
      auth = described_class.new("  special-key  ")
      expect(auth.api_key).to eq("special-key")
    end

    it "accepts nil" do
      auth = described_class.new(nil)
      expect(auth.api_key).to be_nil
    end

    it "converts symbols to strings" do
      auth = described_class.new(:"my-key")
      expect(auth.api_key).to eq("my-key")
    end

    it "validates API key length" do
      expect do
        described_class.new("ab") # Too short
      end.to raise_error(PetstoreApiClient::ValidationError, /at least 3 characters/)
    end

    it "rejects API keys with newlines" do
      expect do
        described_class.new("key\nwith\nnewlines")
      end.to raise_error(PetstoreApiClient::ValidationError, /newline characters/)
    end

    it "doesn't validate nil or empty keys" do
      expect { described_class.new(nil) }.not_to raise_error
      expect { described_class.new("") }.not_to raise_error
    end
  end

  describe ".from_env" do
    it "loads API key from environment variable" do
      ENV["PETSTORE_API_KEY"] = "env-test-key"
      auth = described_class.from_env
      expect(auth.api_key).to eq("env-test-key")
      ENV.delete("PETSTORE_API_KEY")
    end

    it "returns nil API key when env var is not set" do
      ENV.delete("PETSTORE_API_KEY")
      auth = described_class.from_env
      expect(auth.api_key).to be_nil
    end
  end

  describe "#configured?" do
    it "returns true when API key is set" do
      auth = described_class.new("test-key")
      expect(auth.configured?).to be true
    end

    it "returns false when API key is nil" do
      auth = described_class.new(nil)
      expect(auth.configured?).to be false
    end

    it "returns false when API key is empty string" do
      auth = described_class.new("")
      expect(auth.configured?).to be false
    end
  end

  describe "#apply" do
    let(:env) do
      double(
        "Faraday::Env",
        request_headers: {},
        url: double(scheme: "https")
      )
    end

    it "adds api_key header to request" do
      auth = described_class.new("special-key")
      auth.apply(env)

      expect(env.request_headers["api_key"]).to eq("special-key")
    end

    it "does nothing when API key is not configured" do
      auth = described_class.new(nil)
      auth.apply(env)

      expect(env.request_headers).not_to have_key("api_key")
    end

    context "with HTTP (insecure) connection" do
      let(:http_env) do
        double(
          "Faraday::Env",
          request_headers: {},
          url: double(scheme: "http")
        )
      end

      it "warns when sending API key over HTTP" do
        auth = described_class.new("test-key")

        expect do
          auth.apply(http_env)
        end.to output(/WARNING: Sending credentials over insecure HTTP/).to_stderr
      end

      it "still adds the header even with warning" do
        auth = described_class.new("test-key")

        # Suppress warning output for test
        allow(auth).to receive(:warn)

        auth.apply(http_env)
        expect(http_env.request_headers["api_key"]).to eq("test-key")
      end
    end

    context "with HTTPS (secure) connection" do
      it "doesn't warn when using HTTPS" do
        auth = described_class.new("test-key")

        expect do
          auth.apply(env)
        end.not_to output.to_stderr
      end
    end
  end

  describe "#type" do
    it "returns authentication type name" do
      auth = described_class.new("test-key")
      expect(auth.type).to eq("ApiKey")
    end
  end

  describe "#inspect" do
    it "masks API key for security" do
      auth = described_class.new("special-key-12345")
      expect(auth.inspect).to match(/spec\*+/)
      expect(auth.inspect).not_to include("special-key-12345")
    end

    it "shows only first 4 characters" do
      auth = described_class.new("abcdefghijk")
      expect(auth.inspect).to include("abcd")
      expect(auth.inspect).not_to include("efghijk")
    end

    it "fully masks short API keys" do
      auth = described_class.new("abc")
      expect(auth.inspect).to include("***")
    end

    it "shows not configured when API key is nil" do
      auth = described_class.new(nil)
      expect(auth.inspect).to include("not configured")
    end
  end

  describe "#to_s" do
    it "aliases inspect" do
      auth = described_class.new("test-key")
      expect(auth.to_s).to eq(auth.inspect)
    end
  end

  describe "constants" do
    it "has correct header name" do
      expect(described_class::HEADER_NAME).to eq("api_key")
    end

    it "has correct environment variable name" do
      expect(described_class::ENV_VAR_NAME).to eq("PETSTORE_API_KEY")
    end

    it "has minimum key length requirement" do
      expect(described_class::MIN_KEY_LENGTH).to eq(3)
    end
  end
end
