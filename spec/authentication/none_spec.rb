# frozen_string_literal: true

require "spec_helper"

RSpec.describe PetstoreApiClient::Authentication::None do
  describe "#apply" do
    let(:env) { double("Faraday::Env", request_headers: {}) }

    it "does not modify request headers" do
      auth = described_class.new
      auth.apply(env)

      expect(env.request_headers).to be_empty
    end

    it "doesn't raise errors" do
      auth = described_class.new
      expect { auth.apply(env) }.not_to raise_error
    end
  end

  describe "#configured?" do
    it "always returns false" do
      auth = described_class.new
      expect(auth.configured?).to be false
    end
  end

  describe "#type" do
    it "returns authentication type name" do
      auth = described_class.new
      expect(auth.type).to eq("None")
    end
  end

  describe "#inspect" do
    it "shows no authentication" do
      auth = described_class.new
      expect(auth.inspect).to include("no authentication")
    end
  end

  describe "#to_s" do
    it "aliases inspect" do
      auth = described_class.new
      expect(auth.to_s).to eq(auth.inspect)
    end
  end
end
