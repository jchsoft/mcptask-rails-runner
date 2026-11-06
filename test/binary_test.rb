# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "stringio"

class BinaryTest < Minitest::Test
  include ColourEnv

  Palette = McptaskRailsRunner::Palette
  VERSION = McptaskRailsRunner::VERSION
  GREEN = Palette::GREEN
  YELLOW = Palette::YELLOW
  RED = Palette::RED
  ORANGE = Palette::ORANGE

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

  # Every platform gem has to be named something a host actually resolves.
  # `arm64-linux` is not: RubyGems calls that architecture aarch64, the two do
  # not match, and every Graviton server, ARM CI runner and Docker container on
  # Apple Silicon quietly resolved the binary-less fallback gem and failed at
  # run time with "mcptask_runner binary not found".
  #
  # The -gnu and -musl entries are the second half of it: a platform gem has to
  # match both libc flavours, which is why `x86_64-linux` was fine all along.
  HOSTS = {
    "arm64-darwin" => %w[arm64-darwin-23 arm64-darwin-24],
    "x86_64-darwin" => %w[x86_64-darwin-22],
    "aarch64-linux" => %w[aarch64-linux-gnu aarch64-linux-musl],
    "x86_64-linux" => %w[x86_64-linux-gnu x86_64-linux-musl]
  }.freeze

  def test_platform_gems_are_named_what_their_hosts_resolve
    HOSTS.each do |platform, hosts|
      assert_includes McptaskRailsRunner::Binary::SUPPORTED_PLATFORMS, platform

      hosts.each do |host|
        assert Gem::Platform.new(platform) =~ Gem::Platform.new(host),
               "a #{host} host does not resolve the #{platform} gem"
      end
    end
  end

  # --- installing the binary outside the gem ---
  #
  # The scheduled job runs whatever binary generated it, and a job pointing into
  # gems/mcptask-rails-runner-<version>-<platform>/libexec dies at the next
  # `bundle update` — which deletes that directory — at 08:00, in a log nobody
  # reads. So install copies the binary out first.

  def test_install_copies_the_binary_out_of_the_gem
    Dir.mktmpdir do |root|
      gem_root = staged_gem(root)
      install_dir = File.join(root, "installed")

      target = install(install_dir: install_dir, gem_root: gem_root)

      assert_equal File.join(install_dir, McptaskRailsRunner::Binary.executable_name), target
      assert File.file?(target), "the binary was not copied out of the gem"
      assert File.executable?(target), "the installed copy is not executable"
      refute target.start_with?(gem_root), "the installed copy is still inside the gem"
    end
  end

  def test_install_overwrites_an_older_installed_copy
    Dir.mktmpdir do |root|
      gem_root = staged_gem(root, body: "#!/bin/sh\necho bundled\n")
      install_dir = File.join(root, "installed")
      stub_installed(install_dir, "0.1.0")

      out = StringIO.new
      target = install(install_dir: install_dir, gem_root: gem_root, out: out)

      assert_equal "#!/bin/sh\necho bundled\n", File.read(target)
      # Overwriting is fine; doing it without saying so is not.
      assert_includes out.string, McptaskRailsRunner::VERSION
      assert_includes out.string, "0.1.0"
    end
  end

  # A host with several projects has several gem versions and one installed
  # binary. A project pinning an older gem must not quietly drag the machine's
  # runner backwards.
  def test_install_keeps_a_newer_installed_binary
    Dir.mktmpdir do |root|
      gem_root = staged_gem(root, body: "#!/bin/sh\necho bundled\n")
      install_dir = File.join(root, "installed")
      existing = stub_installed(install_dir, "9.9.9")

      out = StringIO.new
      target = install(install_dir: install_dir, gem_root: gem_root, out: out)

      assert_equal existing, target
      refute_includes File.read(target), "echo bundled", "the newer binary was overwritten"
      assert_includes out.string, "9.9.9"
    end
  end

  # Writing a launcher to nothing is the failure this whole path exists to
  # prevent, so a gem with no binary in it has to say so and stop.
  def test_install_fails_loudly_when_the_platform_binary_is_missing
    Dir.mktmpdir do |root|
      install_dir = File.join(root, "installed")

      error = assert_raises(McptaskRailsRunner::Error) do
        install(install_dir: install_dir, gem_root: File.join(root, "empty-gem"))
      end

      assert_includes error.message, "MCPTASK_RUNNER_BIN"
      refute File.exist?(File.join(install_dir, McptaskRailsRunner::Binary.executable_name)),
             "a binary was installed despite there being none to install"
    end
  end

  # The override is how an unsupported platform runs at all. Copying over it
  # would replace the operator's own binary with one this gem does not have.
  def test_install_leaves_the_env_override_alone
    Dir.mktmpdir do |root|
      ENV["MCPTASK_RUNNER_BIN"] = "/opt/custom/mcptask_runner"
      install_dir = File.join(root, "installed")

      target = install(install_dir: install_dir, gem_root: staged_gem(root))

      assert_equal "/opt/custom/mcptask_runner", target
      refute File.exist?(File.join(install_dir, McptaskRailsRunner::Binary.executable_name))
    end
  end

  def test_installed_path_names_no_version
    path = McptaskRailsRunner::Binary.installed_path(install_dir: "/home/x/.mcptask/bin")

    assert_equal "/home/x/.mcptask/bin/#{McptaskRailsRunner::Binary.executable_name}", path
    refute_includes path, McptaskRailsRunner::VERSION
  end

  # --- what the operator sees ---
  #
  # This is the first line of `rake mcptask_runner:install`, and what follows
  # it is init's screen. It speaks init's line kinds: a green check for what is
  # done, an orange bang for a warning the run goes on after, a red cross with
  # the step to take for a refusal.

  def test_a_first_install_says_what_happened_in_green
    with_colour_env do
      Dir.mktmpdir do |root|
        out = FakeTTY.new
        install(install_dir: File.join(root, "installed"), gem_root: staged_gem(root), out: out)

        assert_equal "\e[32m✓ mcptask_runner #{VERSION} installed into #{File.join(root, 'installed')}\e[0m\n", out.string
      end
    end
  end

  def test_the_home_directory_is_abbreviated
    with_colour_env do
      Dir.mktmpdir do |root|
        out = StringIO.new
        home = File.join(root, "home")
        Dir.stub(:home, home) do
          install(install_dir: File.join(home, ".mcptask", "bin"), gem_root: staged_gem(root), out: out)
        end

        assert_equal "✓ mcptask_runner #{VERSION} installed into ~/.mcptask/bin\n", out.string
      end
    end
  end

  # Same version on both sides said "(replacing 0.3.49)" before, which says nothing.
  def test_the_same_version_is_already_current
    with_colour_env do
      Dir.mktmpdir do |root|
        install_dir = File.join(root, "installed")
        stub_installed(install_dir, VERSION)
        out = StringIO.new

        install(install_dir: install_dir, gem_root: staged_gem(root), out: out)

        assert_equal "✓ mcptask_runner #{VERSION} is already current\n", out.string
        refute_includes out.string, "replacing"
      end
    end
  end

  def test_replacing_an_older_binary_is_done_and_names_the_old_version
    with_colour_env do
      Dir.mktmpdir do |root|
        install_dir = File.join(root, "installed")
        stub_installed(install_dir, "0.1.0")
        out = FakeTTY.new

        install(install_dir: install_dir, gem_root: staged_gem(root, body: "#!/bin/sh\necho bundled\n"), out: out)

        assert out.string.start_with?("#{GREEN}✓ mcptask_runner #{VERSION} installed into "), out.string
        assert_includes out.string, "(was 0.1.0)"
      end
    end
  end

  # Not what the operator asked for, so not done: the install they ran left the
  # machine on a different version than the gem they ran it from.
  def test_keeping_a_newer_binary_is_an_orange_warning
    with_colour_env("TERM" => "xterm-256color") do
      Dir.mktmpdir do |root|
        install_dir = File.join(root, "installed")
        stub_installed(install_dir, "9.9.9")
        out = FakeTTY.new

        install(install_dir: install_dir, gem_root: staged_gem(root), out: out)

        assert out.string.start_with?("#{ORANGE}! "), out.string
        assert_includes out.string, "9.9.9"
        assert_includes out.string, "Delete that file"
      end
    end
  end

  def test_the_env_override_notice_is_a_yellow_warning_on_a_16_colour_terminal
    with_colour_env("TERM" => "xterm") do
      Dir.mktmpdir do |root|
        ENV["MCPTASK_RUNNER_BIN"] = "/opt/custom/mcptask_runner"
        out = FakeTTY.new

        install(install_dir: File.join(root, "installed"), gem_root: staged_gem(root), out: out)

        assert out.string.start_with?("#{YELLOW}! MCPTASK_RUNNER_BIN is set"), out.string
      end
    end
  end

  def test_a_missing_binary_is_a_red_refusal_with_the_step_and_still_raises
    with_colour_env do
      Dir.mktmpdir do |root|
        out = FakeTTY.new

        assert_raises(McptaskRailsRunner::Error) do
          install(install_dir: File.join(root, "installed"), gem_root: File.join(root, "empty-gem"), out: out)
        end

        assert out.string.start_with?("#{RED}✗ "), out.string
        assert_includes out.string, "bundle install"
        assert_includes out.string, "MCPTASK_RUNNER_BIN"
        assert_equal 1, out.string.lines.size, "the refusal is one line; the exception carries the detail"
      end
    end
  end

  def test_a_failed_copy_is_a_red_refusal_with_the_step_and_still_raises
    with_colour_env do
      Dir.mktmpdir do |root|
        blocker = File.join(root, "installed")
        File.write(blocker, "a file where the directory must be")
        out = FakeTTY.new

        assert_raises(SystemCallError) do
          install(install_dir: blocker, gem_root: staged_gem(root), out: out)
        end

        assert out.string.start_with?("#{RED}✗ could not copy mcptask_runner "), out.string
        assert_includes out.string, "run this task again"
      end
    end
  end

  # The launchers tee this into ~/logs/mcptask_runner/*.log, and CI reads it as
  # text. Escape codes baked into either would be worse than the grey wall.
  def test_a_stream_that_is_not_a_terminal_gets_no_escape_codes
    with_colour_env do
      Dir.mktmpdir do |root|
        install_dir = File.join(root, "installed")
        stub_installed(install_dir, "0.1.0")
        out = StringIO.new

        install(install_dir: install_dir, gem_root: staged_gem(root), out: out)

        refute_includes out.string, "\e["
      end
    end
  end

  def test_no_color_makes_a_terminal_plain_for_every_kind_of_line
    with_colour_env("NO_COLOR" => "1") do
      Dir.mktmpdir do |root|
        install_dir = File.join(root, "installed")
        newer = stub_installed(install_dir, "9.9.9")
        out = FakeTTY.new

        install(install_dir: install_dir, gem_root: staged_gem(root), out: out)
        File.delete(newer)
        assert_raises(McptaskRailsRunner::Error) do
          install(install_dir: install_dir, gem_root: File.join(root, "empty-gem"), out: out)
        end

        refute_includes out.string, "\e["
        assert_includes out.string, "! "
        assert_includes out.string, "✗ "
      end
    end
  end

  private

  def install(install_dir:, gem_root:, out: StringIO.new)
    McptaskRailsRunner::Binary.install!(install_dir: install_dir, gem_root: gem_root, out: out)
  end

  # A gem as RubyGems unpacks it: a versioned, platform-suffixed directory that
  # the next bundle update replaces.
  def staged_gem(root, body: "#!/bin/sh\n")
    gem_root = File.join(root, "gems", "mcptask-rails-runner-#{McptaskRailsRunner::VERSION}-arm64-darwin")
    exe = File.join(gem_root, "libexec", McptaskRailsRunner::Binary.executable_name)
    FileUtils.mkdir_p(File.dirname(exe))
    File.write(exe, body)
    FileUtils.chmod(0o755, exe)
    gem_root
  end

  # An already-installed binary, which answers `version` the way the real one
  # does — that banner line is how install finds out what it would replace.
  def stub_installed(install_dir, version)
    target = File.join(install_dir, McptaskRailsRunner::Binary.executable_name)
    FileUtils.mkdir_p(install_dir)
    File.write(target, "#!/bin/sh\necho '[McptaskRunner] Version: #{version}'\n")
    FileUtils.chmod(0o755, target)
    target
  end
end
