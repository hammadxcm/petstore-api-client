# frozen_string_literal: true

module PetstoreApiClient
  module Authentication
    # Base class for authentication strategies
    # Implements Strategy Pattern - allows different authentication methods
    # to be swapped without changing client code
    #
    # This follows the same pattern as battle-tested gems like:
    # - Octokit (GitHub API client)
    # - Slack-ruby-client
    # - Stripe Ruby library
    class Base
      # Apply authentication to a Faraday request environment
      #
      # @param env [Faraday::Env] The request environment
      # @return [void]
      def apply(env)
        raise NotImplementedError, "#{self.class.name} must implement #apply"
      end

      # Check if this authentication strategy is configured
      # Used to determine if auth should be applied
      #
      # @return [Boolean]
      def configured?
        raise NotImplementedError, "#{self.class.name} must implement #configured?"
      end

      # Human-readable description of authentication type
      # Useful for logging and debugging
      #
      # @return [String]
      def type
        self.class.name.split("::").last
      end

      protected

      # Validates that a credential meets minimum length requirements
      #
      # @param value [String] The credential value to validate
      # @param field_name [String] Name of the field for error messages
      # @param min_length [Integer] Minimum required length
      # @raise [ValidationError] if credential is too short
      # @return [void]
      def validate_credential_length(value, field_name, min_length)
        return if value.length >= min_length

        raise ValidationError,
              "#{field_name} must be at least #{min_length} characters (got #{value.length})"
      end

      # Validates that a credential doesn't contain newline characters
      # Newlines can cause security issues and are never valid in credentials
      #
      # @param value [String] The credential value to validate
      # @param field_name [String] Name of the field for error messages
      # @raise [ValidationError] if credential contains newlines
      # @return [void]
      def validate_no_newlines(value, field_name)
        return unless value.include?("\n") || value.include?("\r")

        raise ValidationError, "#{field_name} contains newline characters"
      end

      # Validates that a credential doesn't have leading/trailing whitespace
      # Whitespace usually indicates copy-paste errors
      #
      # @param value [String] The credential value to validate
      # @param field_name [String] Name of the field for error messages
      # @raise [ValidationError] if credential has whitespace
      # @return [void]
      def validate_no_whitespace(value, field_name)
        return if value == value.strip

        raise ValidationError,
              "#{field_name} has leading/trailing whitespace (did you copy-paste incorrectly?)"
      end

      # Warns if authentication is being sent over insecure HTTP connection
      # This is a security risk as credentials can be intercepted
      #
      # @param env [Faraday::Env] The request environment
      # @return [void]
      def warn_if_insecure!(env)
        return if env.url.scheme == "https"

        warn "[PetstoreApiClient] WARNING: Sending credentials over insecure HTTP connection! " \
             "Use HTTPS in production to protect credentials."
      end

      # Masks a credential for safe display in logs and inspect output
      # Shows first few characters and masks the rest
      #
      # @param value [String] The credential to mask
      # @param visible_chars [Integer] Number of characters to show (default: 3)
      # @return [String] Masked credential string
      def mask_credential(value, visible_chars = 3)
        return "***" if value.length <= visible_chars

        "#{value[0...visible_chars]}#{'*' * (value.length - visible_chars)}"
      end

      # Standard inspect message for unconfigured authenticators
      #
      # @return [String] Inspect message
      def unconfigured_inspect
        "#<#{self.class.name} (not configured)>"
      end
    end
  end
end
