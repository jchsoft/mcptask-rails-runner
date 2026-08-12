# frozen_string_literal: true

require_relative "lib/mcptask_rails_runner/version"

Gem::Specification.new do |spec|
  spec.name = "mcptask-rails-runner"
  spec.version = McptaskRailsRunner::VERSION
  spec.authors = ["Josef Chmel"]
  spec.email = ["info@jchsoft.cz"]

  spec.summary = "mcptask.online autonomous runner for Rails apps"
  spec.description = "Thin Rails wrapper around the mcptask_runner Go binary. " \
                     "Ships the platform-specific binary inside the gem and exposes " \
                     "the same rake tasks as the legacy mcptask_runner gem, delegating 1:1 to the CLI."
  spec.homepage = "https://github.com/jchsoft/mcptask-rails-runner"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Explicit whitelist — nothing outside lib/, the license and the README may
  # ever ship. Platform builds (Rakefile) append exactly one libexec binary.
  spec.files = Dir["lib/**/*.rb", "lib/tasks/*.rake"] + %w[LICENSE README.md]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 6.0"
end
