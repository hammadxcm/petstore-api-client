# frozen_string_literal: true

require "spec_helper"

RSpec.describe ArrayPresenceValidator do
  # Create a test class to use the validator
  let(:test_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :items

      validates :items, array_presence: true
    end
  end

  describe "validation" do
    it "is valid when value is a non-empty array" do
      instance = test_class.new(items: %w[item1 item2])
      expect(instance).to be_valid
    end

    it "is invalid when value is nil" do
      instance = test_class.new(items: nil)
      expect(instance).not_to be_valid
      expect(instance.errors[:items]).to include("must be present")
    end

    it "is invalid when value is not an array" do
      instance = test_class.new(items: "not an array")
      expect(instance).not_to be_valid
      expect(instance.errors[:items]).to include("must be an array")
    end

    it "is invalid when array is empty" do
      instance = test_class.new(items: [])
      expect(instance).not_to be_valid
      expect(instance.errors[:items]).to include("cannot be empty")
    end
  end
end
