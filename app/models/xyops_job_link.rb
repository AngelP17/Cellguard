class XyopsJobLink < ApplicationRecord
  self.table_name = "xyops_job_links"

  belongs_to :incident, optional: true
  belongs_to :agent_execution, optional: true
  belongs_to :error_budget, optional: true
  belongs_to :workflow_run, class_name: "XyopsWorkflowRun", foreign_key: :xyops_workflow_run_id, optional: true
  belongs_to :alert, class_name: "XyopsAlert", foreign_key: :xyops_alert_id, optional: true
  belongs_to :snapshot, class_name: "XyopsSnapshot", foreign_key: :xyops_snapshot_id, optional: true

  validates :role, presence: true, inclusion: { in: %w[trigger evidence remediation context] }

  scope :for_incident, ->(id) { where(incident_id: id) }
  scope :evidence, -> { where(role: "evidence") }
  scope :remediation, -> { where(role: "remediation") }

  def xyops_context
    {
      workflow: workflow_run&.workflow&.name,
      run: workflow_run&.external_id,
      server: workflow_run&.server,
      alert: alert&.title,
      snapshot: snapshot&.summary
    }.compact
  end
end
