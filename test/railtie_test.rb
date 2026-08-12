# frozen_string_literal: true

require "test_helper"
require "open3"

# Load order matters here: a Rails app requires rails before Bundler.require
# reaches this gem. Other tests in this process already required the gem
# without Rails, so the realistic order only exists in a fresh process.
class RailtieTest < Minitest::Test
  LIB = File.expand_path("../lib", __dir__)

  def ruby(code)
    out, status = Open3.capture2e(RbConfig.ruby, "-I", LIB, "-e", code)
    [out, status]
  end

  def test_railtie_loads_and_registers_rake_tasks_when_rails_is_present
    out, status = ruby(<<~RUBY)
      require "rails"
      require "rails/railtie"
      require "mcptask_rails_runner"
      require "rake"

      raise "railtie missing" unless defined?(McptaskRailsRunner::Railtie)

      rake = Rake::Application.new
      Rake.application = rake
      McptaskRailsRunner::Railtie.rake_tasks.each { |block| rake.instance_eval(&block) }
      raise "rake tasks not registered" unless rake.lookup("mcptask_runner:manual:once")
      puts "ok"
    RUBY

    assert status.success?, out
    assert_includes out, "ok"
  end

  def test_gem_loads_without_rails
    out, status = ruby(<<~RUBY)
      require "mcptask_rails_runner"
      raise "railtie should not load outside Rails" if defined?(McptaskRailsRunner::Railtie)
      puts McptaskRailsRunner::VERSION
    RUBY

    assert status.success?, out
    assert_includes out, McptaskRailsRunner::VERSION
  end
end
