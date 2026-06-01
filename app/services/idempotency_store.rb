# frozen_string_literal: true

# In-process idempotency cache for mutation endpoints.
# Clients send an X-Idempotency-Key header; the same key + same body returns the cached response.
# The same key with a different body returns 409 Conflict.
# For multi-process deployments, swap the store for Redis.
class IdempotencyStore
  DEFAULT_TTL = 24 * 60 * 60 # 24 hours
  KEY_MARKER_SUFFIX = ":__key__".freeze

  class << self
    def store
      @store ||= {}
    end

    def fetch(full_key)
      entry = store[full_key]
      return nil unless entry
      return nil if entry[:expires_at] < Time.current

      entry
    end

    def key_used?(key)
      !!store[key_with_marker(key)]
    end

    def save(full_key, status:, body:, ttl: DEFAULT_TTL)
      fingerprint = full_key.split(":", 2).last
      key = full_key.split(":", 2).first
      expires_at = Time.current + ttl

      store[full_key] = { status: status, body: body, expires_at: expires_at }
      store[key_with_marker(key)] = { fingerprint: fingerprint, expires_at: expires_at }
      cleanup!
      store[full_key]
    end

    def reset!
      @store = {}
    end

    private

    def key_with_marker(key)
      "#{key}#{KEY_MARKER_SUFFIX}"
    end

    def cleanup!
      now = Time.current
      store.delete_if { |_, v| v[:expires_at] < now }
    end
  end
end
