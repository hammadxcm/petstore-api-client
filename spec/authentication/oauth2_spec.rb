# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Authentication::OAuth2 do
  describe "#initialize" do
    it "accepts OAuth2 credentials" do
      auth = described_class.new(
        client_id: "my-client-id",
        client_secret: "my-secret",
        token_url: "https://api.example.com/oauth/token"
      )

      expect(auth.client_id).to eq("my-client-id")
      expect(auth.client_secret).to eq("my-secret")
      expect(auth.token_url).to eq("https://api.example.com/oauth/token")
    end

    it "strips whitespace from credentials" do
      auth = described_class.new(
        client_id: "  my-id  ",
        client_secret: "  my-secret  "
      )

      expect(auth.client_id).to eq("my-id")
      expect(auth.client_secret).to eq("my-secret")
    end

    it "accepts nil credentials" do
      auth = described_class.new(client_id: nil, client_secret: nil)

      expect(auth.client_id).to be_nil
      expect(auth.client_secret).to be_nil
    end

    it "uses default token URL when not specified" do
      auth = described_class.new(client_id: "client-id", client_secret: "secret-key")

      expect(auth.token_url).to eq(described_class::DEFAULT_TOKEN_URL)
    end

    it "accepts custom scope" do
      auth = described_class.new(
        client_id: "client-id",
        client_secret: "secret-key",
        scope: "read:pets write:pets"
      )

      expect(auth.scope).to eq("read:pets write:pets")
    end

    it "validates client_id length" do
      expect do
        described_class.new(client_id: "ab", client_secret: "secret123")
      end.to raise_error(PetstoreApiClient::ValidationError, /client_id must be at least 3 characters/)
    end

    it "validates client_secret length" do
      expect do
        described_class.new(client_id: "client-id", client_secret: "ab")
      end.to raise_error(PetstoreApiClient::ValidationError, /client_secret must be at least 3 characters/)
    end

    it "rejects client_id with newlines" do
      expect do
        described_class.new(client_id: "id\nwith\nnewlines", client_secret: "my-secret-key")
      end.to raise_error(PetstoreApiClient::ValidationError, /newline characters/)
    end

    it "rejects client_secret with newlines" do
      expect do
        described_class.new(client_id: "client-id", client_secret: "secret\nline")
      end.to raise_error(PetstoreApiClient::ValidationError, /newline characters/)
    end

    it "doesn't validate when credentials are nil" do
      expect { described_class.new(client_id: nil, client_secret: nil) }.not_to raise_error
    end

    it "doesn't validate when credentials are empty" do
      expect { described_class.new(client_id: "", client_secret: "") }.not_to raise_error
    end
  end

  describe ".from_env" do
    it "loads credentials from environment variables" do
      ENV["PETSTORE_OAUTH2_CLIENT_ID"] = "env-client-id"
      ENV["PETSTORE_OAUTH2_CLIENT_SECRET"] = "env-secret"
      ENV["PETSTORE_OAUTH2_TOKEN_URL"] = "https://env.example.com/token"
      ENV["PETSTORE_OAUTH2_SCOPE"] = "read write"

      auth = described_class.from_env

      expect(auth.client_id).to eq("env-client-id")
      expect(auth.client_secret).to eq("env-secret")
      expect(auth.token_url).to eq("https://env.example.com/token")
      expect(auth.scope).to eq("read write")

      # Cleanup
      ENV.delete("PETSTORE_OAUTH2_CLIENT_ID")
      ENV.delete("PETSTORE_OAUTH2_CLIENT_SECRET")
      ENV.delete("PETSTORE_OAUTH2_TOKEN_URL")
      ENV.delete("PETSTORE_OAUTH2_SCOPE")
    end

    it "uses default token_url when env var not set" do
      ENV.delete("PETSTORE_OAUTH2_TOKEN_URL")
      ENV["PETSTORE_OAUTH2_CLIENT_ID"] = "my-client-id"
      ENV["PETSTORE_OAUTH2_CLIENT_SECRET"] = "my-secret-key"

      auth = described_class.from_env

      expect(auth.token_url).to eq(described_class::DEFAULT_TOKEN_URL)

      ENV.delete("PETSTORE_OAUTH2_CLIENT_ID")
      ENV.delete("PETSTORE_OAUTH2_CLIENT_SECRET")
    end

    it "returns nil credentials when env vars not set" do
      ENV.delete("PETSTORE_OAUTH2_CLIENT_ID")
      ENV.delete("PETSTORE_OAUTH2_CLIENT_SECRET")

      auth = described_class.from_env

      expect(auth.client_id).to be_nil
      expect(auth.client_secret).to be_nil
    end
  end

  describe "#configured?" do
    it "returns true when credentials are set" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")

      expect(auth.configured?).to be true
    end

    it "returns false when client_id is nil" do
      auth = described_class.new(client_id: nil, client_secret: "my-secret-key")

      expect(auth.configured?).to be false
    end

    it "returns false when client_secret is nil" do
      auth = described_class.new(client_id: "my-client-id", client_secret: nil)

      expect(auth.configured?).to be false
    end

    it "returns false when both are nil" do
      auth = described_class.new(client_id: nil, client_secret: nil)

      expect(auth.configured?).to be false
    end

    it "returns false when client_id is empty string" do
      auth = described_class.new(client_id: "", client_secret: "my-secret-key")

      expect(auth.configured?).to be false
    end

    it "returns false when client_secret is empty string" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "")

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

    let(:mock_token) do
      double(
        "OAuth2::AccessToken",
        token: "mock-access-token",
        expired?: false,
        expires_at: Time.now.to_i + 3600
      )
    end

    it "adds Authorization header with Bearer token" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
      allow(auth).to receive(:fetch_token!) do
        auth.instance_variable_set(:@access_token, mock_token)
        mock_token
      end

      auth.apply(env)

      expect(env.request_headers["Authorization"]).to eq("Bearer mock-access-token")
    end

    it "does nothing when not configured" do
      auth = described_class.new(client_id: nil, client_secret: nil)

      auth.apply(env)

      expect(env.request_headers).not_to have_key("Authorization")
    end

    it "fetches token if not present" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")

      expect(auth).to receive(:fetch_token!) do
        auth.instance_variable_set(:@access_token, mock_token)
        mock_token
      end

      auth.apply(env)
    end

    it "refreshes token if expired" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
      expired_token = double("OAuth2::AccessToken", expired?: true)

      # Set expired token
      auth.instance_variable_set(:@access_token, expired_token)

      expect(auth).to receive(:fetch_token!) do
        auth.instance_variable_set(:@access_token, mock_token)
        mock_token
      end

      auth.apply(env)
    end

    context "with HTTP (insecure) connection" do
      let(:http_env) do
        double(
          "Faraday::Env",
          request_headers: {},
          url: double(scheme: "http")
        )
      end

      it "warns when sending credentials over HTTP" do
        auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
        allow(auth).to receive(:fetch_token!) do
          auth.instance_variable_set(:@access_token, mock_token)
          mock_token
        end

        expect do
          auth.apply(http_env)
        end.to output(/WARNING: Sending credentials over insecure HTTP/).to_stderr
      end

      it "still adds header even with warning" do
        auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
        allow(auth).to receive(:fetch_token!) do
          auth.instance_variable_set(:@access_token, mock_token)
          mock_token
        end
        allow(auth).to receive(:warn) # Suppress warning output

        auth.apply(http_env)

        expect(http_env.request_headers["Authorization"]).to eq("Bearer mock-access-token")
      end
    end

    context "with HTTPS (secure) connection" do
      it "doesn't warn when using HTTPS" do
        auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
        allow(auth).to receive(:fetch_token!) do
          auth.instance_variable_set(:@access_token, mock_token)
          mock_token
        end

        expect do
          auth.apply(env)
        end.not_to output.to_stderr
      end
    end
  end

  describe "#fetch_token!" do
    it "fetches access token using client credentials flow" do
      auth = described_class.new(
        client_id: "test-id",
        client_secret: "test-secret",
        token_url: "https://api.example.com/oauth/token"
      )

      mock_client = double("OAuth2::Client")
      mock_credentials = double("ClientCredentials")
      mock_token = double("AccessToken", token: "access-token-123")

      allow(auth).to receive(:build_oauth2_client).and_return(mock_client)
      allow(mock_client).to receive(:client_credentials).and_return(mock_credentials)
      allow(mock_credentials).to receive(:get_token).with(scope: nil).and_return(mock_token)

      result = auth.fetch_token!

      expect(result).to eq(mock_token)
    end

    it "passes scope when configured" do
      auth = described_class.new(
        client_id: "test-id",
        client_secret: "test-secret",
        scope: "read:pets write:pets"
      )

      mock_client = double("OAuth2::Client")
      mock_credentials = double("ClientCredentials")
      mock_token = double("AccessToken")

      allow(auth).to receive(:build_oauth2_client).and_return(mock_client)
      allow(mock_client).to receive(:client_credentials).and_return(mock_credentials)
      expect(mock_credentials).to receive(:get_token).with(scope: "read:pets write:pets").and_return(mock_token)

      auth.fetch_token!
    end

    it "raises AuthenticationError on OAuth2 error" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")

      mock_client = double("OAuth2::Client")
      allow(auth).to receive(:build_oauth2_client).and_return(mock_client)
      allow(mock_client).to receive(:client_credentials).and_raise(
        ::OAuth2::Error.new(double(status: 401, body: "Unauthorized"))
      )

      expect do
        auth.fetch_token!
      end.to raise_error(PetstoreApiClient::AuthenticationError, /OAuth2 token fetch failed/)
    end
  end

  describe "#token_expired?" do
    it "returns true when no token exists" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")

      expect(auth.token_expired?).to be true
    end

    it "returns true when token is expired" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
      expired_token = double("AccessToken", expired?: true)
      auth.instance_variable_set(:@access_token, expired_token)

      expect(auth.token_expired?).to be true
    end

    it "returns false when token is valid" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
      valid_token = double(
        "AccessToken",
        expired?: false,
        expires_at: Time.now.to_i + 3600 # Expires in 1 hour
      )
      auth.instance_variable_set(:@access_token, valid_token)

      expect(auth.token_expired?).to be false
    end

    it "returns true when token expires within buffer window" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
      expiring_soon = double(
        "AccessToken",
        expired?: false,
        expires_at: Time.now.to_i + 30 # Expires in 30 seconds (within 60s buffer)
      )
      auth.instance_variable_set(:@access_token, expiring_soon)

      expect(auth.token_expired?).to be true
    end

    it "returns false when token has no expiration" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")
      no_expiry = double("AccessToken", expired?: false, expires_at: nil)
      auth.instance_variable_set(:@access_token, no_expiry)

      expect(auth.token_expired?).to be false
    end
  end

  describe "#type" do
    it "returns OAuth2 as type" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")

      expect(auth.type).to eq("OAuth2")
    end
  end

  describe "#inspect" do
    it "masks client_secret for security" do
      auth = described_class.new(client_id: "my-app", client_secret: "secret123456")

      expect(auth.inspect).to match(/sec\*+/)
      expect(auth.inspect).not_to include("secret123456")
    end

    it "shows client_id in plain text" do
      auth = described_class.new(client_id: "my-app", client_secret: "my-secret-key")

      expect(auth.inspect).to include("client_id=my-app")
    end

    it "shows only first 3 characters of secret" do
      auth = described_class.new(client_id: "app", client_secret: "abcdefghijk")

      expect(auth.inspect).to include("abc")
      expect(auth.inspect).not_to include("defghijk")
    end

    it "fully masks short secrets" do
      auth = described_class.new(client_id: "app", client_secret: "abc")

      expect(auth.inspect).to include("***")
    end

    it "shows not configured when credentials missing" do
      auth = described_class.new(client_id: nil, client_secret: nil)

      expect(auth.inspect).to include("not configured")
    end

    it "shows token status" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")

      # No token
      expect(auth.inspect).to include("no token")

      # With valid token
      valid_token = double(
        "AccessToken",
        expired?: false,
        expires_at: Time.now.to_i + 3600
      )
      auth.instance_variable_set(:@access_token, valid_token)
      expect(auth.inspect).to include("token valid")

      # With expired token
      expired_token = double("AccessToken", expired?: true)
      auth.instance_variable_set(:@access_token, expired_token)
      expect(auth.inspect).to include("token expired")
    end
  end

  describe "#to_s" do
    it "aliases inspect" do
      auth = described_class.new(client_id: "my-client-id", client_secret: "my-secret-key")

      expect(auth.to_s).to eq(auth.inspect)
    end
  end

  describe "constants" do
    it "has default token URL" do
      expect(described_class::DEFAULT_TOKEN_URL).to eq("https://petstore.swagger.io/oauth/token")
    end

    it "has default scope" do
      expect(described_class::DEFAULT_SCOPE).to eq("read:pets write:pets")
    end

    it "has environment variable names" do
      expect(described_class::ENV_CLIENT_ID).to eq("PETSTORE_OAUTH2_CLIENT_ID")
      expect(described_class::ENV_CLIENT_SECRET).to eq("PETSTORE_OAUTH2_CLIENT_SECRET")
      expect(described_class::ENV_TOKEN_URL).to eq("PETSTORE_OAUTH2_TOKEN_URL")
      expect(described_class::ENV_SCOPE).to eq("PETSTORE_OAUTH2_SCOPE")
    end

    it "has token refresh buffer" do
      expect(described_class::TOKEN_REFRESH_BUFFER).to eq(60)
    end
  end
end
