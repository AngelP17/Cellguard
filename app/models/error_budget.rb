class ErrorBudget < ApplicationRecord
  belongs_to :shard

  def allowed_error_rate
    1.0 - slo_target.to_f
  end

  def gate_open?
    release_gate_open
  end

  def stale?
    evaluated_at.nil? || evaluated_at < 2.minutes.ago
  end
end
