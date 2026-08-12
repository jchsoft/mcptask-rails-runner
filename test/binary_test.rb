# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class BinaryTest < Minitest::Test
  def teardown
    ENV.delete("MCPTASK_RUNNER_BIN")
  end

  def test_env_override_wins
    ENV["MCPTASK_RUNNER_BIN"] = "/opt/custom/mcptask_runner"
    assert_equal "/opt/custom/mcptask_runner", McptaskRailsRunner::Binary.path
  end

  def test_empty_env_override_is_ignored
    ENV["MCPTASK_RUNNER_BIN"] = ""
    assert_raises(McptaskRailsRunner::Error) do
      McptaskRailsRunner::Binary.path(gem_root: Dir.mktmpdir)
    end
  end

  def test_finds_bundled_binary_in_libexec
    Dir.mktmpdir do |root|
      exe = File.join(root, "libexec", McptaskRailsRunner::Binary.executable_name)
      FileUtils.mkdir_p(File.dirname(exe))
      File.write(exe, "#!/bin/sh\n")
      assert_equal exe, McptaskRailsRunner::Binary.path(gem_root: root)
    end
  end

  def test_missing_binary_raises_with_platform_hint
    error = assert_raises(McptaskRailsRunner::Error) do
      McptaskRailsRunner::Binary.path(gem_root: Dir.mktmpdir)
    end
    assert_includes error.message, "MCPTASK_RUNNER_BIN"
    assert_includes error.message, Gem::Platform.local.to_s
  end

  def test_gem_root_points_at_repo_root
    assert File.file?(File.join(McptaskRailsRunner::Binary::GEM_ROOT, "mcptask-rails-runner.gemspec"))
  end
end
