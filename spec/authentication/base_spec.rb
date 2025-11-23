# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Authentication::Base do
  # Create a test subclass to test abstract methods
  let(:test_auth_class) do
    Class.new(described_class) do
      def apply(env); end

      def configured?
        true
      end
    end
  end

  describe "#apply" do
    it "raises NotImplementedError in base class" do
      auth = described_class.new
      env = double("Faraday::Env")

      expect do
        auth.apply(env)
      end.to raise_error(NotImplementedError, /must implement #apply/)
    end

    it "can be overridden in subclasses" do
      auth = test_auth_class.new
      env = double("Faraday::Env")

      expect { auth.apply(env) }.not_to raise_error
    end
  end

  describe "#configured?" do
    it "raises NotImplementedError in base class" do
      auth = described_class.new

      expect do
        auth.configured?
      end.to raise_error(NotImplementedError, /must implement #configured\?/)
    end

    it "can be overridden in subclasses" do
      auth = test_auth_class.new

      expect(auth.configured?).to be true
    end
  end

  describe "#type" do
    it "returns the class name without module" do
      auth = described_class.new
      expect(auth.type).to eq("Base")
    end

    it "works with real authentication classes" do
      api_key_auth = PetstoreApiClient::Authentication::ApiKey.new("test")
      expect(api_key_auth.type).to eq("ApiKey")

      none_auth = PetstoreApiClient::Authentication::None.new
      expect(none_auth.type).to eq("None")
    end
  end
end
