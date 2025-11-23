# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets default base_url" do
      expect(config.base_url).to eq("https://petstore.swagger.io/v2")
    end

    it "sets default timeout" do
      expect(config.timeout).to eq(30)
    end

    it "sets default open_timeout" do
      expect(config.open_timeout).to eq(10)
    end

    it "sets api_key to nil by default" do
      expect(config.api_key).to be_nil
    end

    # New retry-related defaults
    it "enables retry by default" do
      expect(config.retry_enabled).to be true
    end

    it "sets default max_retries to 2" do
      expect(config.max_retries).to eq(2)
    end
  end

  describe "#configure" do
    it "allows configuration via block" do
      config.configure do |c|
        c.base_url = "https://custom-api.com"
        c.api_key = "test-key"
        c.timeout = 60
      end

      expect(config.base_url).to eq("https://custom-api.com")
      expect(config.api_key).to eq("test-key")
      expect(config.timeout).to eq(60)
    end

    it "allows disabling retries" do
      config.configure do |c|
        c.retry_enabled = false
      end

      expect(config.retry_enabled).to be false
    end

    it "allows customizing max retries" do
      config.configure do |c|
        c.max_retries = 5
      end

      expect(config.max_retries).to eq(5)
    end
  end

  describe "#validate!" do
    it "validates successfully with default config" do
      expect { config.validate! }.not_to raise_error
    end

    it "raises error if base_url is nil" do
      config.base_url = nil
      expect { config.validate! }.to raise_error(PetstoreApiClient::ValidationError, /base_url/)
    end

    it "raises error if base_url is empty string" do
      config.base_url = ""
      expect { config.validate! }.to raise_error(PetstoreApiClient::ValidationError, /base_url/)
    end
  end

  describe "authentication configuration" do
    describe "#api_key=" do
      it "accepts a string API key" do
        config.api_key = "special-key"
        expect(config.api_key).to eq("special-key")
      end

      it "accepts nil" do
        config.api_key = nil
        expect(config.api_key).to be_nil
      end

      it "loads from environment when :from_env is passed" do
        ENV["PETSTORE_API_KEY"] = "env-key-123"
        config.api_key = :from_env
        expect(config.api_key).to eq("env-key-123")
        ENV.delete("PETSTORE_API_KEY")
      end

      it "returns nil from environment when var is not set" do
        ENV.delete("PETSTORE_API_KEY")
        config.api_key = :from_env
        expect(config.api_key).to be_nil
      end
    end

    describe "#authenticator" do
      it "returns ApiKey authenticator when api_key is set" do
        config.api_key = "test-key"
        expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::ApiKey)
        expect(config.authenticator.configured?).to be true
      end

      it "returns None authenticator when api_key is nil" do
        config.api_key = nil
        expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::None)
        expect(config.authenticator.configured?).to be false
      end

      it "returns None authenticator when api_key is empty string" do
        config.api_key = ""
        expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::None)
      end

      it "memoizes the authenticator" do
        config.api_key = "test-key"
        auth1 = config.authenticator
        auth2 = config.authenticator
        expect(auth1).to be(auth2)
      end
    end

    describe "#reset_authenticator!" do
      it "clears memoized authenticator" do
        config.api_key = "test-key"
        auth1 = config.authenticator

        config.reset_authenticator!
        auth2 = config.authenticator

        expect(auth2).not_to be(auth1)
      end
    end

    describe "#configure" do
      it "resets authenticator when config changes" do
        config.api_key = "old-key"
        old_auth = config.authenticator

        config.configure do |c|
          c.api_key = "new-key"
        end

        new_auth = config.authenticator
        expect(new_auth).not_to be(old_auth)
      end
    end
  end

  describe "pagination configuration" do
    it "sets default page size" do
      expect(config.default_page_size).to eq(25)
    end

    it "sets max page size" do
      expect(config.max_page_size).to eq(100)
    end

    it "allows customizing pagination settings" do
      config.configure do |c|
        c.default_page_size = 50
        c.max_page_size = 200
      end

      expect(config.default_page_size).to eq(50)
      expect(config.max_page_size).to eq(200)
    end
  end

  describe "OAuth2 configuration" do
    describe "defaults" do
      it "sets auth_strategy to :api_key by default" do
        expect(config.auth_strategy).to eq(:api_key)
      end

      it "sets oauth2_client_id to nil by default" do
        expect(config.oauth2_client_id).to be_nil
      end

      it "sets oauth2_client_secret to nil by default" do
        expect(config.oauth2_client_secret).to be_nil
      end

      it "sets oauth2_token_url to nil by default" do
        expect(config.oauth2_token_url).to be_nil
      end

      it "sets oauth2_scope to nil by default" do
        expect(config.oauth2_scope).to be_nil
      end
    end

    describe "#auth_strategy=" do
      it "accepts :none strategy" do
        config.auth_strategy = :none
        expect(config.auth_strategy).to eq(:none)
      end

      it "accepts :api_key strategy" do
        config.auth_strategy = :api_key
        expect(config.auth_strategy).to eq(:api_key)
      end

      it "accepts :oauth2 strategy" do
        config.auth_strategy = :oauth2
        expect(config.auth_strategy).to eq(:oauth2)
      end

      it "accepts :both strategy" do
        config.auth_strategy = :both
        expect(config.auth_strategy).to eq(:both)
      end
    end

    describe "OAuth2 credential setters" do
      it "allows setting oauth2_client_id" do
        config.oauth2_client_id = "my-client-id"
        expect(config.oauth2_client_id).to eq("my-client-id")
      end

      it "allows setting oauth2_client_secret" do
        config.oauth2_client_secret = "my-secret"
        expect(config.oauth2_client_secret).to eq("my-secret")
      end

      it "allows setting oauth2_token_url" do
        config.oauth2_token_url = "https://custom.com/token"
        expect(config.oauth2_token_url).to eq("https://custom.com/token")
      end

      it "allows setting oauth2_scope" do
        config.oauth2_scope = "read:pets write:pets"
        expect(config.oauth2_scope).to eq("read:pets write:pets")
      end
    end

    describe "#authenticator with auth_strategy" do
      context "when auth_strategy is :none" do
        it "returns None authenticator" do
          config.auth_strategy = :none
          expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::None)
          expect(config.authenticator.configured?).to be false
        end
      end

      context "when auth_strategy is :api_key" do
        it "returns ApiKey authenticator when api_key is configured" do
          config.auth_strategy = :api_key
          config.api_key = "special-key"
          expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::ApiKey)
          expect(config.authenticator.configured?).to be true
        end

        it "returns None authenticator when api_key is not configured" do
          config.auth_strategy = :api_key
          config.api_key = nil
          expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::None)
          expect(config.authenticator.configured?).to be false
        end
      end

      context "when auth_strategy is :oauth2" do
        it "returns OAuth2 authenticator when credentials are configured" do
          config.auth_strategy = :oauth2
          config.oauth2_client_id = "test-client-id"
          config.oauth2_client_secret = "test-secret-key"
          expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::OAuth2)
          expect(config.authenticator.configured?).to be true
        end

        it "returns None authenticator when credentials are not configured" do
          config.auth_strategy = :oauth2
          config.oauth2_client_id = nil
          config.oauth2_client_secret = nil
          expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::None)
          expect(config.authenticator.configured?).to be false
        end

        it "uses default token URL when not specified" do
          config.auth_strategy = :oauth2
          config.oauth2_client_id = "test-client-id"
          config.oauth2_client_secret = "test-secret-key"
          authenticator = config.authenticator
          expect(authenticator.token_url).to eq(PetstoreApiClient::Authentication::OAuth2::DEFAULT_TOKEN_URL)
        end

        it "uses custom token URL when specified" do
          config.auth_strategy = :oauth2
          config.oauth2_client_id = "test-client-id"
          config.oauth2_client_secret = "test-secret-key"
          config.oauth2_token_url = "https://custom.com/oauth/token"
          authenticator = config.authenticator
          expect(authenticator.token_url).to eq("https://custom.com/oauth/token")
        end

        it "passes scope to OAuth2 authenticator" do
          config.auth_strategy = :oauth2
          config.oauth2_client_id = "test-client-id"
          config.oauth2_client_secret = "test-secret-key"
          config.oauth2_scope = "read:pets write:pets"
          authenticator = config.authenticator
          expect(authenticator.scope).to eq("read:pets write:pets")
        end
      end

      context "when auth_strategy is :both" do
        it "returns Composite authenticator with both strategies" do
          config.auth_strategy = :both
          config.api_key = "special-key"
          config.oauth2_client_id = "test-client-id"
          config.oauth2_client_secret = "test-secret-key"

          authenticator = config.authenticator
          expect(authenticator).to be_a(PetstoreApiClient::Authentication::Composite)
          expect(authenticator.configured?).to be true
          expect(authenticator.configured_types).to contain_exactly("ApiKey", "OAuth2")
        end

        it "includes only API Key when OAuth2 is not configured" do
          config.auth_strategy = :both
          config.api_key = "special-key"
          config.oauth2_client_id = nil
          config.oauth2_client_secret = nil

          authenticator = config.authenticator
          expect(authenticator).to be_a(PetstoreApiClient::Authentication::Composite)
          expect(authenticator.configured_types).to eq(["ApiKey"])
        end

        it "includes only OAuth2 when API Key is not configured" do
          config.auth_strategy = :both
          config.api_key = nil
          config.oauth2_client_id = "test-client-id"
          config.oauth2_client_secret = "test-secret-key"

          authenticator = config.authenticator
          expect(authenticator).to be_a(PetstoreApiClient::Authentication::Composite)
          expect(authenticator.configured_types).to eq(["OAuth2"])
        end

        it "returns empty Composite when neither is configured" do
          config.auth_strategy = :both
          config.api_key = nil
          config.oauth2_client_id = nil
          config.oauth2_client_secret = nil

          authenticator = config.authenticator
          expect(authenticator).to be_a(PetstoreApiClient::Authentication::Composite)
          expect(authenticator.configured?).to be false
          expect(authenticator.strategies).to be_empty
        end
      end

      context "when auth_strategy is invalid" do
        it "raises ConfigurationError" do
          config.auth_strategy = :invalid_strategy
          expect { config.authenticator }.to raise_error(
            PetstoreApiClient::ConfigurationError,
            /Invalid auth_strategy: :invalid_strategy/
          )
        end

        it "shows valid options in error message" do
          config.auth_strategy = :bad
          expect { config.authenticator }.to raise_error(
            PetstoreApiClient::ConfigurationError,
            /Must be one of: :none, :api_key, :oauth2, :both/
          )
        end
      end
    end

    describe "authenticator memoization with auth_strategy" do
      it "memoizes OAuth2 authenticator" do
        config.auth_strategy = :oauth2
        config.oauth2_client_id = "test-client-id"
        config.oauth2_client_secret = "test-secret-key"

        auth1 = config.authenticator
        auth2 = config.authenticator
        expect(auth1).to be(auth2)
      end

      it "memoizes Composite authenticator" do
        config.auth_strategy = :both
        config.api_key = "special-key"
        config.oauth2_client_id = "test-client-id"
        config.oauth2_client_secret = "test-secret-key"

        auth1 = config.authenticator
        auth2 = config.authenticator
        expect(auth1).to be(auth2)
      end
    end

    describe "#reset_authenticator! with auth_strategy changes" do
      it "rebuilds authenticator when switching from api_key to oauth2" do
        config.auth_strategy = :api_key
        config.api_key = "special-key"
        api_key_auth = config.authenticator
        expect(api_key_auth).to be_a(PetstoreApiClient::Authentication::ApiKey)

        config.auth_strategy = :oauth2
        config.oauth2_client_id = "test-client-id"
        config.oauth2_client_secret = "test-secret-key"
        config.reset_authenticator!

        oauth2_auth = config.authenticator
        expect(oauth2_auth).to be_a(PetstoreApiClient::Authentication::OAuth2)
        expect(oauth2_auth).not_to be(api_key_auth)
      end

      it "rebuilds authenticator when switching to :both" do
        config.auth_strategy = :api_key
        config.api_key = "special-key"
        api_key_auth = config.authenticator

        config.auth_strategy = :both
        config.oauth2_client_id = "test-client-id"
        config.oauth2_client_secret = "test-secret-key"
        config.reset_authenticator!

        composite_auth = config.authenticator
        expect(composite_auth).to be_a(PetstoreApiClient::Authentication::Composite)
        expect(composite_auth).not_to be(api_key_auth)
      end
    end

    describe "#configure with OAuth2" do
      it "allows configuring OAuth2 via block" do
        config.configure do |c|
          c.auth_strategy = :oauth2
          c.oauth2_client_id = "my-client-id"
          c.oauth2_client_secret = "my-secret-key"
          c.oauth2_token_url = "https://custom.com/token"
          c.oauth2_scope = "read:pets"
        end

        expect(config.auth_strategy).to eq(:oauth2)
        expect(config.oauth2_client_id).to eq("my-client-id")
        expect(config.oauth2_client_secret).to eq("my-secret-key")
        expect(config.oauth2_token_url).to eq("https://custom.com/token")
        expect(config.oauth2_scope).to eq("read:pets")
      end

      it "allows configuring dual authentication via block" do
        config.configure do |c|
          c.auth_strategy = :both
          c.api_key = "special-key"
          c.oauth2_client_id = "my-client-id"
          c.oauth2_client_secret = "my-secret-key"
        end

        authenticator = config.authenticator
        expect(authenticator).to be_a(PetstoreApiClient::Authentication::Composite)
        expect(authenticator.configured_types).to contain_exactly("ApiKey", "OAuth2")
      end

      it "automatically resets authenticator after configuration" do
        config.auth_strategy = :api_key
        config.api_key = "old-key"
        old_auth = config.authenticator

        config.configure do |c|
          c.auth_strategy = :oauth2
          c.oauth2_client_id = "test-client-id"
          c.oauth2_client_secret = "test-secret-key"
        end

        new_auth = config.authenticator
        expect(new_auth).not_to be(old_auth)
        expect(new_auth).to be_a(PetstoreApiClient::Authentication::OAuth2)
      end
    end
  end
end
