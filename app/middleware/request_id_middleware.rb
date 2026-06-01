# frozen_string_literal: true

# Assigns a unique request ID to every incoming request for correlation in logs.
# Honors X-Request-Id from upstream if present and well-formed, otherwise generates.
class RequestIdMiddleware
  HEADER = "X-Request-Id".freeze
  THREAD_KEY = :cellguard_request_id
  ID_FORMAT = /\A[A-Za-z0-9_\-]{1,128}\z/.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request_id = env["HTTP_X_REQUEST_ID"]
    request_id = nil unless request_id.is_a?(String) && request_id.match?(ID_FORMAT)
    request_id ||= SecureRandom.uuid

    env["action_dispatch.request_id"] = request_id
    Thread.current[THREAD_KEY] = request_id

    status, headers, body = @app.call(env)
    headers[HEADER] = request_id
    [status, headers, body]
  ensure
    Thread.current[THREAD_KEY] = nil
  end

  def self.current
    Thread.current[THREAD_KEY]
  end
end
