# frozen_string_literal: true

require "json"

# Structured JSON logger. Inherits from ActiveSupport::Logger so Rails picks it up.
# Each log line is one JSON object with timestamp, level, request_id, message, and any payload.
class StructuredJsonLogger < ActiveSupport::Logger
  def call(severity, time, progname, msg)
    payload = {
      timestamp: time.iso8601(3),
      level: severity,
      request_id: RequestIdMiddleware.current,
      pid: Process.pid
    }
    payload[:progname] = progname if progname.present?

    case msg
    when Hash
      payload.merge!(msg)
    when Exception
      payload[:message] = msg.message
      payload[:exception] = msg.class.name
      payload[:backtrace] = msg.backtrace&.first(10)
    when String
      payload[:message] = msg
    else
      payload[:message] = msg.inspect
    end

    super(severity, time, progname, payload.to_json + "\n")
  end

  def self.format_message(payload)
    "#{payload.to_json}\n"
  end
end
