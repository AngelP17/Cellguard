class XyopsAlert < ApplicationRecord
  self.table_name = "xyops_alerts"

  belongs_to :connection, class_name: "XyopsConnection", foreign_key: :xyops_connection_id
  belongs_to :workflow_run, class_name: "XyopsWorkflowRun", foreign_key: :xyops_workflow_run_id, optional: true

  has_many :job_links, class_name: "XyopsJobLink", foreign_key: :xyops_alert_id, dependent: :nullify

  validates :external_id, :title, :fired_at, presence: true
  validates :severity, inclusion: { in: %w[info warning critical] }

  scope :active, -> { where(resolved_at: nil) }
  scope :critical, -> { where(severity: "critical") }
  scope :recent, -> { order(fired_at: :desc) }

  def resolved?
    resolved_at.present?
  end

  def active?
    !resolved?
  end
end
