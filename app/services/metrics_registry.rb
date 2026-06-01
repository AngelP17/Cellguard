# frozen_string_literal: true

# Lightweight in-process metrics registry.
# Exposes counts, gauges, and timings without a Prometheus dependency.
# For production scraping, point an exporter at GET /api/metrics.
class MetricsRegistry
  class << self
    def counters
      @counters ||= Hash.new(0)
    end

    def gauges
      @gauges ||= Hash.new(0)
    end

    def timings
      @timings ||= Hash.new { |h, k| h[k] = [] }
    end

    def increment(name, by: 1, tags: {})
      key = serialize_key(name, tags)
      counters[key] += by
    end

    def gauge(name, value, tags: {})
      key = serialize_key(name, tags)
      gauges[key] = value
    end

    def time(name, tags: {})
      key = serialize_key(name, tags)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
    ensure
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2) if start
      timings[key] << duration_ms if duration_ms
      timings[key].shift while timings[key].size > 1000
    end

    def snapshot
      {
        counters: counters.dup,
        gauges: gauges.dup,
        timings: timings.transform_values { |v| { count: v.size, avg_ms: (v.sum / v.size).round(2), p95_ms: percentile(v, 0.95) } }
      }
    end

    def reset!
      @counters = Hash.new(0)
      @gauges = Hash.new(0)
      @timings = Hash.new { |h, k| h[k] = [] }
    end

    private

    def serialize_key(name, tags)
      return name.to_s if tags.blank?
      "#{name}{#{tags.sort.map { |k, v| "#{k}=#{v}" }.join(',')}}"
    end

    def percentile(values, p)
      return 0 if values.empty?
      sorted = values.sort
      idx = (p * (sorted.length - 1)).round
      sorted[idx].round(2)
    end
  end
end
