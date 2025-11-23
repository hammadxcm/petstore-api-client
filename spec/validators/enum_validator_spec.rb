# frozen_string_literal: true

require "spec_helper"

RSpec.describe EnumValidator do
  # Create a test class to use the validator
  let(:test_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :status

      validates :status, enum: { in: %w[active inactive pending] }
    end
  end

  let(:test_class_with_nil) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :status

      validates :status, enum: { in: %w[active inactive], allow_nil: true }
    end
  end

  describe "validation" do
    it "is valid when value is in the allowed set" do
      instance = test_class.new(status: "active")
      expect(instance).to be_valid
    end

    it "is invalid when value is not in the allowed set" do
      instance = test_class.new(status: "invalid")
      expect(instance).not_to be_valid
      expect(instance.errors[:status].first).to match(/must be one of/)
    end

    it "is invalid when value is nil and allow_nil is false" do
      instance = test_class.new(status: nil)
      expect(instance).not_to be_valid
    end

    context "with allow_nil option" do
      it "is valid when value is nil" do
        instance = test_class_with_nil.new(status: nil)
        expect(instance).to be_valid
      end

      it "is valid when value is in the allowed set" do
        instance = test_class_with_nil.new(status: "active")
        expect(instance).to be_valid
      end

      it "is invalid when value is not in the allowed set" do
        instance = test_class_with_nil.new(status: "pending")
        expect(instance).not_to be_valid
      end
    end
  end
end
