# frozen_string_literal: true

require "rake/testtask"
require "rubygems/package"
require "fileutils"
require_relative "lib/mcptask_rails_runner/version"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

# Ruby gem platform => staged binary directory (bin/fetch-binaries fills
# tmp/binaries/<goos>_<goarch>/ from the jchsoft/mcptask-releases artifacts).
PLATFORM_BINARIES = {
  "arm64-darwin" => "darwin_arm64",
  "x86_64-darwin" => "darwin_amd64",
  # aarch64-linux, not arm64-linux: the latter is not a platform any host
  # resolves, so its gem is published and unreachable. The staged directory
  # keeps the Go toolchain's own name for the architecture.
  "aarch64-linux" => "linux_arm64",
  "x86_64-linux" => "linux_amd64",
  "x64-mingw-ucrt" => "windows_amd64"
}.freeze

def build_gem_for(platform)
  # .load memoizes, and package:all builds several platforms in one process —
  # without the dup the second build inherits the first one's platform and files.
  spec = Gem::Specification.load("mcptask-rails-runner.gemspec").dup

  if platform
    exe = platform == "x64-mingw-ucrt" ? "mcptask_runner.exe" : "mcptask_runner"
    staged = File.join("tmp/binaries", PLATFORM_BINARIES.fetch(platform), exe)
    abort "missing staged binary #{staged} — run bin/fetch-binaries first" unless File.file?(staged)

    FileUtils.mkdir_p("libexec")
    FileUtils.cp(staged, File.join("libexec", exe))
    FileUtils.chmod(0o755, File.join("libexec", exe))

    spec.platform = Gem::Platform.new(platform)
    spec.files += [File.join("libexec", exe)]
  end

  FileUtils.mkdir_p("pkg")
  package = Gem::Package.build(spec)
  FileUtils.mv(package, File.join("pkg", package))
  puts "built pkg/#{package}"
ensure
  FileUtils.rm_f(Dir["libexec/mcptask_runner*"])
end

namespace :package do
  PLATFORM_BINARIES.each_key do |platform|
    desc "Build the #{platform} platform gem (binary from tmp/binaries)"
    task platform do
      build_gem_for(platform)
    end
  end

  desc "Build the binary-less ruby platform gem (fallback with instructive error)"
  task :ruby do
    build_gem_for(nil)
  end

  desc "Build every platform gem plus the ruby fallback"
  task all: PLATFORM_BINARIES.keys + ["ruby"]
end

# rubygems/release-gem invokes `rake build` and pushes everything in pkg/.
desc "Alias for package:all"
task build: "package:all"
