# frozen_string_literal: true

require_relative "mcptask_rails_runner/version"

module McptaskRailsRunner
  class Error < StandardError; end

  # Validates a rake bracket argument such as manual:story[123].
  def self.piece_id!(value, name, example)
    id = Integer(value, exception: false)
    raise ArgumentError, "#{name} is required and must be a positive integer (usage: rake '#{example}')" if id.nil? || id < 1

    id.to_s
  end
end

require_relative "mcptask_rails_runner/binary"

# Only inside a booted Rails app — rails/railtie needs active_support loaded,
# and outside Rails there is nothing to hook the rake tasks into.
require_relative "mcptask_rails_runner/railtie" if defined?(::Rails::Railtie)
