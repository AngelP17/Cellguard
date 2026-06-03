class XyopsConnection < ApplicationRecord
  self.table_name = "xyops_connections"

  has_many :workflows, class_name: "XyopsWorkflow", foreign_key: :xyops_connection_id, dependent: :destroy
  has_many :alerts, class_name: "XyopsAlert", foreign_key: :xyops_connection_id, dependent: :destroy
  has_many :snapshots, class_name: "XyopsSnapshot", foreign_key: :xyops_connection_id, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[connected degraded disconnected] }

  scope :connected, -> { where(status: "connected") }

  def connected?
    status == "connected"
  end

  def heartbeat!
    update!(last_heartbeat_at: Time.current, status: "connected")
  end

  def mark_degraded!(reason: nil)
    update!(status: "degraded", metadata: (metadata || {}).merge("last_degrade_reason" => reason, "degraded_at" => Time.current.iso8601))
  end

  def self.ensure_default_stub!
    find_or_create_by!(name: "local-xyops") do |c|
      c.base_url = "stub://local"
      c.status = "connected"
      c.connected_at = Time.current
      c.last_heartbeat_at = Time.current
      c.config = { mode: "simulator", demo_fabric: true }
    end
  end

  def self.primary
    find_by(name: "local-xyops") || ensure_default_stub!
  end

  def mode
    (config.is_a?(Hash) ? (config["mode"] || config[:mode]) : nil) || "simulator"
  end


  # For real xyOps connections (see Xyops::Client)
  # Set config: { "base_url" => "http://localhost:3012", "api_key" => "muJm8T6QSzqQzuO6MvbOdtlB", "group" => "main" }
  def api_key
    config.is_a?(Hash) ? (config["api_key"] || config[:api_key]) : nil
  end

  def real_base_url
    return nil if base_url.to_s.start_with?("stub://")
    base_url.presence
  end

  def snapshot_group
    (config.is_a?(Hash) ? (config["group"] || config[:group]) : nil) || "main"
  end

  def real?
    real_base_url.present?
  end
end

