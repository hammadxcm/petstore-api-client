# frozen_string_literal: true

module EnvHelper
  # Temporarily sets environment variables for the duration of a block
  # Automatically cleans up and restores original values afterward
  #
  # @param env_vars [Hash] Hash of environment variable names to values
  # @yield Block to execute with the environment variables set
  # @return [Object] Result of the block
  #
  # @example
  #   with_env("API_KEY" => "test-key") do
  #     # Code that uses ENV["API_KEY"]
  #   end
  #   # ENV["API_KEY"] is automatically restored
  def with_env(env_vars)
    original_values = {}

    # Store original values and set new ones
    env_vars.each do |key, value|
      original_values[key] = ENV.fetch(key, nil)
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value.to_s
      end
    end

    yield
  ensure
    # Restore original values
    original_values.each do |key, original_value|
      if original_value.nil?
        ENV.delete(key)
      else
        ENV[key] = original_value
      end
    end
  end

  # Sets environment variables for the duration of an example
  # Use this in before blocks or let statements
  #
  # @param env_vars [Hash] Hash of environment variable names to values
  #
  # @example In spec file
  #   before do
  #     set_env("API_KEY" => "test-key")
  #   end
  #
  #   after do
  #     clear_env("API_KEY")
  #   end
  def set_env(env_vars)
    env_vars.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value.to_s
      end
    end
  end

  # Clears specified environment variables
  #
  # @param keys [Array<String>, String] Environment variable key(s) to clear
  def clear_env(*keys)
    keys.flatten.each { |key| ENV.delete(key) }
  end

  # Clears all Petstore-related environment variables
  # Useful in after blocks to ensure test isolation
  def clear_petstore_env
    ENV.keys.select { |k| k.start_with?("PETSTORE_") }.each { |k| ENV.delete(k) }
  end
end

# Include helper in all specs
RSpec.configure do |config|
  config.include EnvHelper

  # Automatically clear Petstore env vars after each test for isolation
  config.after do
    clear_petstore_env
  end
end
