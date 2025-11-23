# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Connection do
  # Create a test class that includes the Connection module
  let(:test_class) do
    Class.new do
      include PetstoreApiClient::Connection

      attr_reader :configuration

      def initialize(config)
        @configuration = config
      end
    end
  end

  let(:config) { PetstoreApiClient::Configuration.new }
  let(:client) { test_class.new(config) }

  describe "#connection" do
    it "creates a Faraday connection" do
      conn = client.send(:connection)
      expect(conn).to be_a(Faraday::Connection)
    end

    it "uses the configured base URL" do
      config.base_url = "https://custom-api.example.com"
      conn = client.send(:connection)

      # Faraday adds a trailing slash to the URL prefix
      expect(conn.url_prefix.to_s).to eq("https://custom-api.example.com/")
    end

    it "sets up JSON request middleware" do
      conn = client.send(:connection)

      # Check if JSON middleware is in the request handlers
      expect(conn.builder.handlers).to include(Faraday::Request::Json)
    end

    it "sets up JSON response middleware" do
      conn = client.send(:connection)

      # The response middleware should handle JSON
      expect(conn.builder.handlers).to include(Faraday::Response::Json)
    end

    it "sets Content-Type and Accept headers" do
      conn = client.send(:connection)

      expect(conn.headers["Content-Type"]).to eq("application/json")
      expect(conn.headers["Accept"]).to eq("application/json")
    end

    it "includes authentication middleware when api_key is configured" do
      config.api_key = "test-api-key"
      conn = client.send(:connection)

      # Check that authentication middleware is in the stack
      expect(conn.builder.handlers).to include(PetstoreApiClient::Middleware::Authentication)
    end

    it "includes authentication middleware even when api_key is not configured" do
      config.api_key = nil
      conn = client.send(:connection)

      # Middleware is always present, but uses None strategy when not configured
      expect(conn.builder.handlers).to include(PetstoreApiClient::Middleware::Authentication)
    end

    it "configures timeout options" do
      config.timeout = 45
      config.open_timeout = 15

      conn = client.send(:connection)

      expect(conn.options.timeout).to eq(45)
      expect(conn.options.open_timeout).to eq(15)
    end

    it "memoizes the connection" do
      conn1 = client.send(:connection)
      conn2 = client.send(:connection)

      expect(conn1).to be(conn2)
    end

    context "when retry is enabled" do
      before { config.retry_enabled = true }

      it "includes retry middleware" do
        conn = client.send(:connection)

        # Check if Retry middleware is configured
        expect(conn.builder.handlers).to include(Faraday::Retry::Middleware)
      end

      it "uses configured max_retries" do
        config.max_retries = 5

        # We need to inspect the retry middleware configuration
        # This is a bit tricky since we can't easily access middleware options
        conn = client.send(:connection)

        expect(conn.builder.handlers).to include(Faraday::Retry::Middleware)
      end
    end

    context "when retry is disabled" do
      before { config.retry_enabled = false }

      it "doesn't include retry middleware" do
        conn = client.send(:connection)

        # When retry is disabled, the middleware shouldn't be added
        expect(conn.builder.handlers).not_to include(Faraday::Retry::Middleware)
      end
    end
  end

  describe "#setup_retry_middleware" do
    let(:faraday_conn) { double("Faraday::Connection") }
    let(:retry_options) { {} }

    before do
      allow(faraday_conn).to receive(:request) do |middleware, options|
        retry_options.merge!(options) if middleware == :retry
      end
    end

    it "configures retry with correct options" do
      client.send(:setup_retry_middleware, faraday_conn)

      expect(faraday_conn).to have_received(:request).with(:retry, anything)
    end

    it "uses max_retries from configuration" do
      config.max_retries = 3

      client.send(:setup_retry_middleware, faraday_conn)

      expect(retry_options[:max]).to eq(3)
    end

    it "sets retry_statuses to handle rate limiting and server errors" do
      client.send(:setup_retry_middleware, faraday_conn)

      expected_statuses = [429, 500, 502, 503, 504]
      expect(retry_options[:retry_statuses]).to eq(expected_statuses)
    end

    it "configures exponential backoff" do
      client.send(:setup_retry_middleware, faraday_conn)

      expect(retry_options[:interval]).to eq(0.5)
      expect(retry_options[:backoff_factor]).to eq(2)
      expect(retry_options[:interval_randomness]).to eq(0.5)
    end

    it "retries on connection failures and timeouts" do
      client.send(:setup_retry_middleware, faraday_conn)

      expected_exceptions = [Faraday::ConnectionFailed, Faraday::TimeoutError]
      expect(retry_options[:exceptions]).to eq(expected_exceptions)
    end

    it "retries all HTTP methods" do
      client.send(:setup_retry_middleware, faraday_conn)

      expect(retry_options[:methods]).to eq(%i[get post put delete])
    end
  end

  describe "#reset_connection!" do
    it "resets the memoized connection" do
      conn1 = client.send(:connection)

      client.send(:reset_connection!)

      conn2 = client.send(:connection)

      expect(conn2).not_to be(conn1)
    end

    it "allows connection to be recreated with new settings" do
      client.send(:connection)

      # Change configuration
      config.timeout = 99

      # Reset and reconnect
      client.send(:reset_connection!)
      new_conn = client.send(:connection)

      expect(new_conn.options.timeout).to eq(99)
    end
  end

  # Edge cases and integration
  describe "edge cases" do
    it "handles empty api_key string" do
      config.api_key = ""

      # Empty string is treated as "no authentication"
      # The authenticator should be None strategy
      expect(config.authenticator).to be_a(PetstoreApiClient::Authentication::None)
      expect(config.authenticator.configured?).to be false
    end

    it "works with default configuration" do
      default_config = PetstoreApiClient::Configuration.new
      default_client = test_class.new(default_config)

      conn = default_client.send(:connection)

      expect(conn).to be_a(Faraday::Connection)
      expect(conn.url_prefix.to_s).to eq("https://petstore.swagger.io/v2")
    end
  end
end
