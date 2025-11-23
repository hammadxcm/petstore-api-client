# frozen_string_literal: true

# Configure SimpleCov for code coverage tracking
require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  enable_coverage :branch
  # Minimum coverage will be enforced after integration tests are complete
  # minimum_coverage line: 90
end

require "petstore_api_client"
require "webmock/rspec"
require "vcr"

# Load support files (shared examples, helpers, etc.)
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri body]
  }
  # Filter sensitive data if needed
  config.filter_sensitive_data("<API_KEY>") { "special-key" }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Disable external HTTP requests by default
  config.before(:each) do
    WebMock.disable_net_connect!(allow_localhost: false)
  end
end
