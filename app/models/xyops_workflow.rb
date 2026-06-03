class XyopsWorkflow < ApplicationRecord
  self.table_name = "xyops_workflows"

  belongs_to :connection, class_name: "XyopsConnection", foreign_key: :xyops_connection_id
  has_many :runs, class_name: "XyopsWorkflowRun", foreign_key: :xyops_workflow_id, dependent: :destroy

  validates :external_id, :name, presence: true
  validates :status, inclusion: { in: %w[active paused archived] }

  scope :active, -> { where(status: "active") }
  scope :recent, -> { order(last_run_at: :desc, updated_at: :desc) }

  def latest_run
    runs.order(started_at: :desc).first
  end

  def failed_runs_count
    runs.where(status: "failed").count
  end
end
