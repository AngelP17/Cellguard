# frozen_string_literal: true

module Xyops
  # Thin wrapper / config manager. In future can hold auth, circuit breaking, etc.
  class Connection
    def self.default
      XyopsConnection.ensure_default_stub!
    end

    def self.healthy?
      default.connected?
    end
  end
end
