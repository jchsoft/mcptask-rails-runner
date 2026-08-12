# frozen_string_literal: true

module McptaskRailsRunner
  # Locates and executes the bundled Go binary.
  module Binary
    GEM_ROOT = File.expand_path("../..", __dir__)

    SUPPORTED_PLATFORMS = %w[
      arm64-darwin
      x86_64-darwin
      arm64-linux
      x86_64-linux
      x64-mingw-ucrt
    ].freeze

    module_function

    def executable_name
      Gem.win_platform? ? "mcptask_runner.exe" : "mcptask_runner"
    end

    # Absolute path to the bundled binary. Never resolved through PATH: the
    # binary shares the mcptask_runner name with the legacy gem's rake
    # namespace, and a PATH lookup could pick up a stale or wrong install.
    def path(gem_root: GEM_ROOT)
      override = ENV["MCPTASK_RUNNER_BIN"]
      return override unless override.nil? || override.empty?

      exe = File.join(gem_root, "libexec", executable_name)
      return exe if File.file?(exe)

      raise Error, <<~MSG
        mcptask_runner binary not found at #{exe}.

        The platform gem for #{Gem::Platform.local} was probably not installed.
        Supported platforms: #{SUPPORTED_PLATFORMS.join(', ')}.

        On a supported platform, re-run `bundle install` (and make sure the
        platform is in Gemfile.lock: `bundle lock --add-platform #{Gem::Platform.local}`).
        On an unsupported platform, install the binary from
        https://github.com/jchsoft/mcptask-releases and point the
        MCPTASK_RUNNER_BIN environment variable at it.
      MSG
    end

    # Replaces the current process, so the binary's exit code and signal
    # handling reach the caller (rake) unchanged.
    def exec!(*args)
      Kernel.exec(path, *args)
    end
  end
end
