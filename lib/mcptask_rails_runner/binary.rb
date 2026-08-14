# frozen_string_literal: true

require "fileutils"

module McptaskRailsRunner
  # Locates, installs and executes the bundled Go binary.
  module Binary
    GEM_ROOT = File.expand_path("../..", __dir__)

    SUPPORTED_PLATFORMS = %w[
      arm64-darwin
      x86_64-darwin
      arm64-linux
      x86_64-linux
      x64-mingw-ucrt
    ].freeze

    # Where the binary is installed to live, outside every gem directory.
    #
    # The scheduled job runs this path, and it has to be one that survives a
    # `bundle update`: a job pointing into
    # gems/mcptask-rails-runner-<version>-<platform>/libexec dies the moment the
    # gem is bumped, at 08:00, in a log nobody reads. Under the runner's own
    # ~/.mcptask rather than /usr/local/bin, because `bundle install` has no
    # sudo and a gem cannot write there. The Go side knows the same path — see
    # InstalledBinary in internal/install/schedule.go.
    INSTALL_DIR = File.join(Dir.home, ".mcptask", "bin")

    # The line `mcptask_runner version` prints the version on.
    VERSION_LINE = /Version:\s*(\S+)/

    module_function

    def executable_name
      Gem.win_platform? ? "mcptask_runner.exe" : "mcptask_runner"
    end

    # Absolute path to the binary this gem runs. Never resolved through PATH:
    # the binary shares the mcptask_runner name with the legacy gem's rake
    # namespace, and a PATH lookup could pick up a stale or wrong install.
    def path(gem_root: GEM_ROOT)
      override = ENV["MCPTASK_RUNNER_BIN"]
      return override unless override.nil? || override.empty?

      bundled_path(gem_root: gem_root)
    end

    # The copy that ships inside this gem, which is the one the Gemfile pins.
    def bundled_path(gem_root: GEM_ROOT)
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

    # The version-free path the installed copy lives at.
    def installed_path(install_dir: INSTALL_DIR)
      File.join(install_dir, executable_name)
    end

    # Copies the bundled binary out of the gem, and returns what to run.
    #
    # The gem bootstraps the binary; it does not host it. Everything the
    # scheduled job touches has to outlive `bundle update`, and a gem directory
    # does not — so install and update put a copy where nothing but they will
    # ever move it. A copy rather than a symlink: a link into the gem's libexec
    # dangles on the same bundle update, which is the identical 08:00 failure
    # moved one step along, and Windows wants a privilege for symlinks besides.
    #
    # Teaching the launcher to run `bundle exec rake` instead would fix the path
    # and put bundler and Gemfile.lock back into the 08:00 path — the layer the
    # Go port set out to remove.
    #
    # Newest wins, and says so. A host with several projects has several gem
    # versions and one installed binary, so a project pinning an older gem must
    # not quietly drag the machine's runner backwards.
    def install!(install_dir: INSTALL_DIR, gem_root: GEM_ROOT, out: $stdout)
      override = ENV["MCPTASK_RUNNER_BIN"]
      unless override.nil? || override.empty?
        out.puts "[mcptask_runner] MCPTASK_RUNNER_BIN is set — running #{override} " \
                 "and leaving #{installed_path(install_dir: install_dir)} alone."
        return override
      end

      source = bundled_path(gem_root: gem_root)
      target = installed_path(install_dir: install_dir)

      existing = installed_version(target)
      if existing && existing > Gem::Version.new(VERSION)
        out.puts "[mcptask_runner] #{target} already holds #{existing}, which is newer than this " \
                 "gem's #{VERSION} — keeping it. Delete that file to install this gem's binary instead."
        return target
      end

      copy(source, target)
      out.puts "[mcptask_runner] installed mcptask_runner #{VERSION} into #{target}" \
               "#{existing ? " (replacing #{existing})" : ''}."
      target
    end

    # Replaces the current process, so the binary's exit code and signal
    # handling reach the caller (rake) unchanged.
    def exec!(*args)
      Kernel.exec(path, *args)
    end

    # Installs the binary outside the gem first, then runs that copy.
    #
    # Used by install and update, the two tasks that generate the scheduled job:
    # the job runs whichever binary is executing them, so it has to be the copy
    # at the version-free path rather than the one inside this gem.
    def exec_installed!(*args)
      Kernel.exec(install!, *args)
    end

    # What the installed copy reports about itself, or nil when there is none —
    # or when it cannot be asked, which a stray file at that path cannot be.
    #
    # Asked of the binary rather than recorded in a marker file beside it: the
    # binary is what actually runs at 08:00, and a marker can only be right
    # about installs that went through here.
    def installed_version(target)
      return nil unless File.file?(target)

      banner = IO.popen([target, "version"], err: File::NULL, &:read)
      raw = banner.to_s[VERSION_LINE, 1]
      raw && Gem::Version.new(raw)
    rescue StandardError
      nil
    end

    # Written beside the target and renamed into place: a half-copied binary
    # over a working one is a scheduled job that fails on a corrupt file, and
    # the rename also sidesteps the ETXTBSY a running copy would give.
    def copy(source, target)
      FileUtils.mkdir_p(File.dirname(target))
      staged = "#{target}.new"
      FileUtils.cp(source, staged)
      FileUtils.chmod(0o755, staged)
      File.rename(staged, target)
    end
  end
end
