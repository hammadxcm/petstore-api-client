# frozen_string_literal: true

# Custom validator for required array fields
# ActiveModel's presence validator doesn't handle empty arrays correctly
class ArrayPresenceValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.nil?
      record.errors.add(attribute, "must be present")
    elsif !value.is_a?(Array)
      record.errors.add(attribute, "must be an array")
    elsif value.empty?
      record.errors.add(attribute, "cannot be empty")
    end
  end
end
