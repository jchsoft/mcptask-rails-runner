# frozen_string_literal: true

require "rails/railtie"

module McptaskRailsRunner
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/mcptask_runner.rake", __dir__)
    end
  end
end
