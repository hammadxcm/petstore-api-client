# frozen_string_literal: true

# Custom enum validator - ActiveModel's inclusion validator doesn't quite work the way we want
# for status enums, so rolling our own
class EnumValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil? && options[:allow_nil]

    allowed_values = options[:in] || options[:within]
    return if allowed_values.include?(value)

    record.errors.add(
      attribute,
      "must be one of: #{allowed_values.join(", ")}, but got '#{value}'"
    )
  end
end
