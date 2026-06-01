# frozen_string_literal: true

# Simple in-process rate limiter using a fixed window in memory.
# For multi-process / multi-host deployments, swap the store for Redis.
# Limits per client IP, configurable per-path.
class RateLimitMiddleware
  DEFAULT_PATHS = {
    "/api/audit-logs" => { limit: 60, window: 60 },
    "/api/incidents/" => { limit: 120, window: 60 },
    "/api/agents/" => { limit: 120, window: 60 },
    "/api/chaos/" => { limit: 30, window: 60 },
    "/api/release-gate/override" => { limit: 30, window: 60 }
  }.freeze

  def initialize(app, paths: DEFAULT_PATHS)
    @app = app
    @paths = paths
    @buckets = {}
    @mutex = Mutex.new
  end

  def call(env)
    config = match_config(env["PATH_INFO"])
    return @app.call(env) unless config

    key = build_key(env, config)
    now = Time.current.to_f
    window_start = now - config[:window]

    @mutex.synchronize do
      bucket = (@buckets[key] ||= [])
      bucket.reject! { |t| t < window_start }
      if bucket.size >= config[:limit]
        return rate_limited_response(config)
      end
      bucket << now
    end

    status, headers, body = @app.call(env)
    headers["X-RateLimit-Limit"] = config[:limit].to_s
    headers["X-RateLimit-Remaining"] = [config[:limit] - @buckets[key].size, 0].max.to_s
    [status, headers, body]
  end

  private

  def match_config(path)
    @paths.find { |prefix, _| path.start_with?(prefix) }&.last
  end

  def build_key(env, config)
    ip = env["action_dispatch.remote_ip"].to_s rescue env["REMOTE_ADDR"].to_s
    "#{ip}:#{config[:limit]}:#{config[:window]}"
  end

  def rate_limited_response(config)
    body = { error: "rate_limited", message: "Too many requests. Try again in #{config[:window]} seconds." }
    [429, { "Content-Type" => "application/json" }, [body.to_json]]
  end
end
