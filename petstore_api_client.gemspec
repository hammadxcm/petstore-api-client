# frozen_string_literal: true

require_relative "lib/petstore_api_client/version"

Gem::Specification.new do |spec|
  spec.name = "petstore_api_client"
  spec.version = PetstoreApiClient::VERSION
  spec.authors = ["Hammad Khan"]
  spec.email = ["hammadkhanxcm@gmail.com"]

  spec.summary = "Production-ready Ruby client for Swagger Petstore API with OAuth2 support"
  spec.description = "Production-ready Ruby client for the Swagger Petstore API. " \
                     "Features OAuth2 & API Key authentication, automatic retries with exponential backoff, " \
                     "rate limiting, pagination, comprehensive validation, and 96.91% test coverage. " \
                     "Built with SOLID principles and industry best practices."
  spec.homepage = "https://github.com/hammadxcm/petstore-api-client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = "https://github.com/hammadxcm/petstore-api-client"
  spec.metadata["bug_tracker_uri"] = "https://github.com/hammadxcm/petstore-api-client/issues"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/petstore_api_client"
  spec.metadata["github_repo"] = "https://github.com/hammadxcm/petstore-api-client"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activemodel", ">= 6.0", "< 9.0"
  spec.add_dependency "activesupport", ">= 6.0", "< 9.0"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "oauth2", "~> 2.0"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.18"
end
