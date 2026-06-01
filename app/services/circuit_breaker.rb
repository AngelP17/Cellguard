# frozen_string_literal: true

# Simple circuit breaker for external service calls.
# Opens after `failure_threshold` consecutive failures, stays open for `reset_timeout`,
# then allows one trial call. If that succeeds, closes the circuit.
class CircuitBreaker
  STATES = %i[closed open half_open].freeze

  attr_reader :name, :failure_threshold, :reset_timeout, :on_open, :on_close, :on_half_open

  def initialize(name:, failure_threshold: 5, reset_timeout: 30, exceptions: [StandardError])
    @name = name
    @failure_threshold = failure_threshold
    @reset_timeout = reset_timeout
    @exceptions = exceptions
    @mutex = Mutex.new
    @state = :closed
    @failure_count = 0
    @opened_at = nil
    @on_open = -> {}
    @on_close = -> {}
    @on_half_open = -> {}
  end

  def state
    @mutex.synchronize { maybe_transition_to_half_open; @state }
  end

  def call
    ensure_can_execute!
    begin
      result = yield
      record_success
      result
    rescue *@exceptions => e
      record_failure(e)
      raise
    end
  end

  def open?
    state == :open
  end

  def closed?
    state == :closed
  end

  def half_open?
    state == :half_open
  end

  private

  def ensure_can_execute!
    @mutex.synchronize do
      maybe_transition_to_half_open
      raise CircuitOpenError.new("Circuit '#{@name}' is open", name: @name) if @state == :open
    end
  end

  def record_success
    @mutex.synchronize do
      @failure_count = 0
      if @state == :half_open
        @state = :closed
        @opened_at = nil
        on_close.call
      end
    end
  end

  def record_failure(error)
    @mutex.synchronize do
      @failure_count += 1
      if @state == :half_open || @failure_count >= @failure_threshold
        @state = :open
        @opened_at = Time.current
        on_open.call(error)
      end
    end
  end

  def maybe_transition_to_half_open
    return unless @state == :open
    return unless @opened_at
    return if Time.current - @opened_at < @reset_timeout

    @state = :half_open
    on_half_open.call
  end

  class CircuitOpenError < StandardError
    attr_reader :circuit_name

    def initialize(message, name:)
      super(message)
      @circuit_name = name
    end
  end
end
