class XyopsSnapshot < ApplicationRecord
  self.table_name = "xyops_snapshots"

  belongs_to :connection, class_name: "XyopsConnection", foreign_key: :xyops_connection_id

  has_many :job_links, class_name: "XyopsJobLink", foreign_key: :xyops_snapshot_id, dependent: :nullify

  validates :server_id, :captured_at, presence: true

  scope :recent, -> { order(captured_at: :desc) }
  scope :for_server, ->(sid) { where(server_id: sid) }

  def healthy?
    (cpu_pct || 0) < 80 && (mem_pct || 0) < 85 && (redis_latency_ms || 0) < 200
  end

  def summary
    {
      server: server_id,
      cpu: cpu_pct,
      mem: mem_pct,
      redis_ms: redis_latency_ms,
      queue: queue_depth,
      captured: captured_at
    }
  end
end
