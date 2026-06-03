class CreateXyopsExecutionFabric < ActiveRecord::Migration[7.1]
  def change
    # Local xyOps connection / fabric registration
    create_table :xyops_connections do |t|
      t.string :name, null: false, default: "local-xyops"
      t.string :base_url, null: false, default: "stub://local"
      t.string :status, null: false, default: "connected" # connected, degraded, disconnected
      t.datetime :connected_at
      t.datetime :last_heartbeat_at
      t.jsonb :config, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :xyops_connections, :name, unique: true
    add_index :xyops_connections, :status

    # Workflows registered from xyOps
    create_table :xyops_workflows do |t|
      t.bigint :xyops_connection_id, null: false
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :description
      t.string :category # e.g. production, remediation, chaos-test, maintenance
      t.string :status, default: "active"
      t.datetime :last_run_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :xyops_workflows, :xyops_connection_id
    add_index :xyops_workflows, [:xyops_connection_id, :external_id], unique: true, name: "idx_xyops_workflows_conn_ext"
    add_index :xyops_workflows, :name

    # Individual workflow run executions from xyOps
    create_table :xyops_workflow_runs do |t|
      t.bigint :xyops_workflow_id, null: false
      t.string :external_id, null: false
      t.string :status, null: false, default: "running" # running, succeeded, failed, cancelled
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :exit_code
      t.string :server_id # e.g. worker-03, print-worker-02
      t.text :logs_summary
      t.jsonb :context, null: false, default: {} # job details, params, queue info
      t.jsonb :metrics, null: false, default: {} # latency, error counts observed
      t.timestamps
    end
    add_index :xyops_workflow_runs, :xyops_workflow_id
    add_index :xyops_workflow_runs, :status
    add_index :xyops_workflow_runs, :started_at
    add_index :xyops_workflow_runs, :server_id
    add_index :xyops_workflow_runs, [:xyops_workflow_id, :external_id], unique: true, name: "idx_xyops_runs_wf_ext"

    # Alerts fired by xyOps monitoring
    create_table :xyops_alerts do |t|
      t.bigint :xyops_connection_id, null: false
      t.string :external_id, null: false
      t.string :severity, null: false, default: "warning" # info, warning, critical
      t.string :title, null: false
      t.text :description
      t.string :source # e.g. queue-latency, cpu-high, workflow-failed
      t.datetime :fired_at, null: false
      t.datetime :resolved_at
      t.bigint :xyops_workflow_run_id
      t.jsonb :context, null: false, default: {}
      t.timestamps
    end
    add_index :xyops_alerts, :xyops_connection_id
    add_index :xyops_alerts, :severity
    add_index :xyops_alerts, :fired_at
    add_index :xyops_alerts, :resolved_at
    add_index :xyops_alerts, [:xyops_connection_id, :external_id], unique: true, name: "idx_xyops_alerts_conn_ext"

    # Server / system snapshots captured by xyOps (for evidence)
    create_table :xyops_snapshots do |t|
      t.bigint :xyops_connection_id, null: false
      t.string :server_id, null: false
      t.datetime :captured_at, null: false
      t.decimal :cpu_pct, precision: 5, scale: 2
      t.decimal :mem_pct, precision: 5, scale: 2
      t.decimal :disk_pct, precision: 5, scale: 2
      t.integer :redis_latency_ms
      t.integer :queue_depth
      t.string :network_status, default: "ok"
      t.jsonb :processes, null: false, default: []
      t.jsonb :network, null: false, default: {}
      t.jsonb :context, null: false, default: {}
      t.timestamps
    end
    add_index :xyops_snapshots, :xyops_connection_id
    add_index :xyops_snapshots, :server_id
    add_index :xyops_snapshots, :captured_at

    # Cross-system linkage table: ties CellGuard incidents/gate decisions/agent runs to xyops artifacts
    create_table :xyops_job_links do |t|
      t.bigint :incident_id
      t.bigint :agent_execution_id
      t.bigint :error_budget_id
      t.bigint :xyops_workflow_run_id
      t.bigint :xyops_alert_id
      t.bigint :xyops_snapshot_id
      t.string :role, null: false, default: "evidence" # trigger, evidence, remediation, context
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    add_index :xyops_job_links, :incident_id
    add_index :xyops_job_links, :agent_execution_id
    add_index :xyops_job_links, :error_budget_id
    add_index :xyops_job_links, :xyops_workflow_run_id
    add_index :xyops_job_links, :xyops_alert_id
    add_index :xyops_job_links, :xyops_snapshot_id
    add_index :xyops_job_links, :role

    # Add foreign keys (optional but good for integrity)
    add_foreign_key :xyops_workflows, :xyops_connections, column: :xyops_connection_id, on_delete: :cascade
    add_foreign_key :xyops_workflow_runs, :xyops_workflows, column: :xyops_workflow_id, on_delete: :cascade
    add_foreign_key :xyops_alerts, :xyops_connections, column: :xyops_connection_id, on_delete: :cascade
    add_foreign_key :xyops_alerts, :xyops_workflow_runs, column: :xyops_workflow_run_id, on_delete: :nullify
    add_foreign_key :xyops_snapshots, :xyops_connections, column: :xyops_connection_id, on_delete: :cascade
    add_foreign_key :xyops_job_links, :incidents, on_delete: :cascade
    add_foreign_key :xyops_job_links, :agent_executions, on_delete: :nullify
  end
end
