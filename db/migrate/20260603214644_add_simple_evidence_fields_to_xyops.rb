class AddSimpleEvidenceFieldsToXyops < ActiveRecord::Migration[7.1]
  def change
    # Add simple denormalized fields for evidence panels and API (per fully-functional spec)
    # These allow UI and API to read directly without complex joins in the demo/evidence paths.

    add_column :xyops_workflow_runs, :workflow_name, :string
    add_column :xyops_workflow_runs, :failed_job_name, :string
    add_column :xyops_workflow_runs, :server_name, :string
    add_column :xyops_workflow_runs, :metadata, :jsonb, default: {}

    add_column :xyops_alerts, :server_name, :string
    add_column :xyops_alerts, :status, :string, default: "active"
    add_column :xyops_alerts, :metadata, :jsonb, default: {}

    add_column :xyops_snapshots, :external_id, :string
    add_column :xyops_snapshots, :server_name, :string
    add_column :xyops_snapshots, :cpu_percent, :decimal, precision: 5, scale: 2
    add_column :xyops_snapshots, :memory_percent, :decimal, precision: 5, scale: 2
    add_column :xyops_snapshots, :network_summary, :string
    add_column :xyops_snapshots, :process_summary, :jsonb, default: {}
    add_column :xyops_snapshots, :metadata, :jsonb, default: {}

    add_column :xyops_job_links, :shard_id, :bigint
    add_column :xyops_job_links, :failed_job_name, :string
    add_column :xyops_job_links, :remediation_available, :boolean, default: false
    add_column :xyops_job_links, :server_name, :string

    add_index :xyops_workflow_runs, :workflow_name
    add_index :xyops_alerts, :server_name
    add_index :xyops_snapshots, :external_id
    add_index :xyops_job_links, :shard_id
    add_index :xyops_job_links, :failed_job_name
  end
end
