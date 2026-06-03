class XyopsWorkflowRun < ApplicationRecord
  self.table_name = "xyops_workflow_runs"

  belongs_to :workflow, class_name: "XyopsWorkflow", foreign_key: :xyops_workflow_id
  has_one :connection, through: :workflow

  has_many :job_links, class_name: "XyopsJobLink", foreign_key: :xyops_workflow_run_id, dependent: :nullify
  has_many :alerts, class_name: "XyopsAlert", foreign_key: :xyops_workflow_run_id, dependent: :nullify

  validates :external_id, :status, :started_at, presence: true
  validates :status, inclusion: { in: %w[running succeeded failed cancelled] }

  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(started_at: :desc) }
  scope :for_shard, ->(shard_name) { where("context->>'shard' = ?", shard_name.to_s) }

  def failed?
    status == "failed"
  end

  def duration_ms
    return nil unless started_at && completed_at
    ((completed_at - started_at) * 1000).to_i
  end

  def server
    server_id.presence || context["server_id"] || "unknown"
  end

  def queue
    context["queue"] || context["queue_namespace"]
  end
end
