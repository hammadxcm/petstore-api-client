# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Authentication::Composite do
  let(:api_key_auth) { PetstoreApiClient::Authentication::ApiKey.new("test-api-key") }
  let(:oauth2_auth) do
    PetstoreApiClient::Authentication::OAuth2.new(
      client_id: "client-id",
      client_secret: "client-secret"
    )
  end
  let(:none_auth) { PetstoreApiClient::Authentication::None.new }

  describe "#initialize" do
    it "accepts an array of strategies" do
      composite = described_class.new([api_key_auth, oauth2_auth])

      expect(composite.strategies).to eq([api_key_auth, oauth2_auth])
    end

    it "accepts empty array" do
      composite = described_class.new([])

      expect(composite.strategies).to be_empty
    end

    it "raises error if strategies is not an array" do
      expect do
        described_class.new("not an array")
      end.to raise_error(ArgumentError, /strategies must be an Array/)
    end

    it "raises error if strategy doesn't inherit from Base" do
      invalid_strategy = double("InvalidStrategy")

      expect do
        described_class.new([invalid_strategy])
      end.to raise_error(ArgumentError, /must inherit from Authentication::Base/)
    end

    it "raises error if strategy doesn't respond to apply" do
      invalid = Class.new(PetstoreApiClient::Authentication::Base) do
        undef apply
      end.new

      expect do
        described_class.new([invalid])
      end.to raise_error(ArgumentError, /must respond to #apply/)
    end

    it "raises error if strategy doesn't respond to configured?" do
      invalid = Class.new(PetstoreApiClient::Authentication::Base) do
        def apply(_env); end
        undef configured?
      end.new

      expect do
        described_class.new([invalid])
      end.to raise_error(ArgumentError, /must respond to #configured\?/)
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

    it "applies all configured strategies" do
      composite = described_class.new([api_key_auth, oauth2_auth])

      # Mock OAuth2 token
      mock_token = double("AccessToken", token: "mock-token", expired?: false, expires_at: Time.now.to_i + 3600)
      allow(oauth2_auth).to receive(:fetch_token!) do
        oauth2_auth.instance_variable_set(:@access_token, mock_token)
        mock_token
      end

      composite.apply(env)

      # Both headers should be present
      expect(env.request_headers["api_key"]).to eq("test-api-key")
      expect(env.request_headers["Authorization"]).to eq("Bearer mock-token")
    end

    it "only applies configured strategies" do
      unconfigured_oauth2 = PetstoreApiClient::Authentication::OAuth2.new(
        client_id: nil,
        client_secret: nil
      )
      composite = described_class.new([api_key_auth, unconfigured_oauth2])

      composite.apply(env)

      # Only API key should be present
      expect(env.request_headers["api_key"]).to eq("test-api-key")
      expect(env.request_headers).not_to have_key("Authorization")
    end

    it "does nothing when no strategies are configured" do
      unconfigured_api_key = PetstoreApiClient::Authentication::ApiKey.new(nil)
      unconfigured_oauth2 = PetstoreApiClient::Authentication::OAuth2.new(client_id: nil, client_secret: nil)
      composite = described_class.new([unconfigured_api_key, unconfigured_oauth2])

      composite.apply(env)

      expect(env.request_headers).to be_empty
    end

    it "does nothing when strategies array is empty" do
      composite = described_class.new([])

      composite.apply(env)

      expect(env.request_headers).to be_empty
    end

    it "applies strategies in order" do
      applied_order = []

      strategy1 = Class.new(PetstoreApiClient::Authentication::Base) do
        define_method(:apply) { |_env| applied_order << :strategy1 }
        define_method(:configured?) { true }
      end.new

      strategy2 = Class.new(PetstoreApiClient::Authentication::Base) do
        define_method(:apply) { |_env| applied_order << :strategy2 }
        define_method(:configured?) { true }
      end.new

      composite = described_class.new([strategy1, strategy2])
      composite.apply(env)

      expect(applied_order).to eq(%i[strategy1 strategy2])
    end
  end

  describe "#configured?" do
    it "returns true when at least one strategy is configured" do
      composite = described_class.new([api_key_auth, oauth2_auth])

      expect(composite.configured?).to be true
    end

    it "returns true when only one strategy is configured" do
      unconfigured = PetstoreApiClient::Authentication::OAuth2.new(client_id: nil, client_secret: nil)
      composite = described_class.new([api_key_auth, unconfigured])

      expect(composite.configured?).to be true
    end

    it "returns false when no strategies are configured" do
      unconfigured_api = PetstoreApiClient::Authentication::ApiKey.new(nil)
      unconfigured_oauth = PetstoreApiClient::Authentication::OAuth2.new(client_id: nil, client_secret: nil)
      composite = described_class.new([unconfigured_api, unconfigured_oauth])

      expect(composite.configured?).to be false
    end

    it "returns false when strategies array is empty" do
      composite = described_class.new([])

      expect(composite.configured?).to be false
    end
  end

  describe "#configured_types" do
    it "returns list of configured strategy types" do
      composite = described_class.new([api_key_auth, oauth2_auth])

      expect(composite.configured_types).to contain_exactly("ApiKey", "OAuth2")
    end

    it "only includes configured strategies" do
      unconfigured = PetstoreApiClient::Authentication::OAuth2.new(client_id: nil, client_secret: nil)
      composite = described_class.new([api_key_auth, unconfigured])

      expect(composite.configured_types).to eq(["ApiKey"])
    end

    it "returns empty array when no strategies configured" do
      unconfigured_api = PetstoreApiClient::Authentication::ApiKey.new(nil)
      composite = described_class.new([unconfigured_api])

      expect(composite.configured_types).to be_empty
    end
  end

  describe "#type" do
    it "returns Composite as type" do
      composite = described_class.new([api_key_auth])

      expect(composite.type).to eq("Composite")
    end
  end

  describe "#inspect" do
    it "shows all strategies" do
      composite = described_class.new([api_key_auth, oauth2_auth])

      expect(composite.inspect).to include("strategies=[ApiKey, OAuth2]")
    end

    it "shows configured strategies separately" do
      unconfigured = PetstoreApiClient::Authentication::OAuth2.new(client_id: nil, client_secret: nil)
      composite = described_class.new([api_key_auth, unconfigured])

      expect(composite.inspect).to include("configured=[ApiKey]")
    end

    it "shows 'none' when no strategies configured" do
      unconfigured_api = PetstoreApiClient::Authentication::ApiKey.new(nil)
      composite = described_class.new([unconfigured_api])

      expect(composite.inspect).to include("configured=[none]")
    end

    it "shows class name" do
      composite = described_class.new([api_key_auth])

      expect(composite.inspect).to include("Composite")
    end
  end

  describe "#to_s" do
    it "aliases inspect" do
      composite = described_class.new([api_key_auth])

      expect(composite.to_s).to eq(composite.inspect)
    end
  end

  describe "integration scenario" do
    it "successfully applies both API Key and OAuth2 authentication" do
      env = double("Faraday::Env", request_headers: {}, url: double(scheme: "https"))

      api_key = PetstoreApiClient::Authentication::ApiKey.new("special-key")
      oauth2 = PetstoreApiClient::Authentication::OAuth2.new(
        client_id: "my-client",
        client_secret: "my-secret"
      )

      # Mock OAuth2 token fetch
      mock_token = double("AccessToken", token: "access-123", expired?: false, expires_at: Time.now.to_i + 3600)
      allow(oauth2).to receive(:fetch_token!) do
        oauth2.instance_variable_set(:@access_token, mock_token)
        mock_token
      end

      composite = described_class.new([api_key, oauth2])
      composite.apply(env)

      # Verify both authentication methods applied
      expect(env.request_headers["api_key"]).to eq("special-key")
      expect(env.request_headers["Authorization"]).to eq("Bearer access-123")
      expect(composite.configured?).to be true
      expect(composite.configured_types).to contain_exactly("ApiKey", "OAuth2")
    end

    it "handles partial configuration gracefully" do
      env = double("Faraday::Env", request_headers: {}, url: double(scheme: "https"))

      # Only API Key configured
      api_key = PetstoreApiClient::Authentication::ApiKey.new("my-key")
      oauth2 = PetstoreApiClient::Authentication::OAuth2.new(client_id: nil, client_secret: nil)

      composite = described_class.new([api_key, oauth2])
      composite.apply(env)

      # Only API Key should be applied
      expect(env.request_headers["api_key"]).to eq("my-key")
      expect(env.request_headers).not_to have_key("Authorization")
      expect(composite.configured?).to be true
      expect(composite.configured_types).to eq(["ApiKey"])
    end
  end
end
