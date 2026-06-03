# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_06_03_214644) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "agent_configs", force: :cascade do |t|
    t.string "key", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_agent_configs_on_key", unique: true
  end

  create_table "agent_executions", force: :cascade do |t|
    t.string "agent_name", null: false
    t.bigint "shard_id"
    t.integer "status", default: 0, null: false
    t.string "action_taken"
    t.jsonb "action_details", default: []
    t.jsonb "result"
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "incident_id"
    t.index ["agent_name", "created_at"], name: "index_agent_executions_on_agent_name_and_created_at"
    t.index ["agent_name"], name: "index_agent_executions_on_agent_name"
    t.index ["created_at"], name: "index_agent_executions_on_created_at"
    t.index ["incident_id"], name: "index_agent_executions_on_incident_id"
    t.index ["shard_id"], name: "index_agent_executions_on_shard_id"
    t.index ["status"], name: "index_agent_executions_on_status"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "shard_id", null: false
    t.string "actor", null: false
    t.string "action", null: false
    t.text "justification", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["shard_id"], name: "index_audit_logs_on_shard_id"
  end

  create_table "error_budgets", force: :cascade do |t|
    t.bigint "shard_id", null: false
    t.decimal "slo_target", precision: 8, scale: 5, default: "0.999", null: false
    t.integer "window_days", default: 30, null: false
    t.datetime "window_start", null: false
    t.decimal "budget_consumed", precision: 12, scale: 8, default: "0.0", null: false
    t.decimal "budget_remaining", precision: 12, scale: 8, default: "1.0", null: false
    t.decimal "current_burn_rate", precision: 10, scale: 4, default: "0.0", null: false
    t.boolean "release_gate_open", default: true, null: false
    t.datetime "evaluated_at"
    t.datetime "violation_started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evaluated_at"], name: "index_error_budgets_on_evaluated_at"
    t.index ["shard_id"], name: "index_error_budgets_on_shard_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.bigint "shard_id", null: false
    t.string "title", null: false
    t.string "severity_label", null: false
    t.string "team_label"
    t.string "service_label"
    t.string "status", default: "active", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_incidents_on_created_at"
    t.index ["shard_id"], name: "index_incidents_on_shard_id"
    t.index ["status"], name: "index_incidents_on_status"
  end

  create_table "job_stats", force: :cascade do |t|
    t.bigint "shard_id", null: false
    t.string "queue_namespace", null: false
    t.datetime "period_start", null: false
    t.datetime "period_end", null: false
    t.integer "job_count", default: 0, null: false
    t.integer "error_count", default: 0, null: false
    t.integer "latency_p95_ms", default: 0, null: false
    t.jsonb "meta", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["period_end"], name: "index_job_stats_on_period_end"
    t.index ["shard_id", "queue_namespace", "period_start", "period_end"], name: "idx_job_stats_dedupe", unique: true
    t.index ["shard_id"], name: "index_job_stats_on_shard_id"
  end

  create_table "shards", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_shards_on_name", unique: true
  end

  create_table "xyops_alerts", force: :cascade do |t|
    t.bigint "xyops_connection_id", null: false
    t.string "external_id", null: false
    t.string "severity", default: "warning", null: false
    t.string "title", null: false
    t.text "description"
    t.string "source"
    t.datetime "fired_at", null: false
    t.datetime "resolved_at"
    t.bigint "xyops_workflow_run_id"
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "server_name"
    t.string "status", default: "active"
    t.jsonb "metadata", default: {}
    t.index ["fired_at"], name: "index_xyops_alerts_on_fired_at"
    t.index ["resolved_at"], name: "index_xyops_alerts_on_resolved_at"
    t.index ["server_name"], name: "index_xyops_alerts_on_server_name"
    t.index ["severity"], name: "index_xyops_alerts_on_severity"
    t.index ["xyops_connection_id", "external_id"], name: "idx_xyops_alerts_conn_ext", unique: true
    t.index ["xyops_connection_id"], name: "index_xyops_alerts_on_xyops_connection_id"
  end

  create_table "xyops_connections", force: :cascade do |t|
    t.string "name", default: "local-xyops", null: false
    t.string "base_url", default: "stub://local", null: false
    t.string "status", default: "connected", null: false
    t.datetime "connected_at"
    t.datetime "last_heartbeat_at"
    t.jsonb "config", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_xyops_connections_on_name", unique: true
    t.index ["status"], name: "index_xyops_connections_on_status"
  end

  create_table "xyops_job_links", force: :cascade do |t|
    t.bigint "incident_id"
    t.bigint "agent_execution_id"
    t.bigint "error_budget_id"
    t.bigint "xyops_workflow_run_id"
    t.bigint "xyops_alert_id"
    t.bigint "xyops_snapshot_id"
    t.string "role", default: "evidence", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "shard_id"
    t.string "failed_job_name"
    t.boolean "remediation_available", default: false
    t.string "server_name"
    t.index ["agent_execution_id"], name: "index_xyops_job_links_on_agent_execution_id"
    t.index ["error_budget_id"], name: "index_xyops_job_links_on_error_budget_id"
    t.index ["failed_job_name"], name: "index_xyops_job_links_on_failed_job_name"
    t.index ["incident_id"], name: "index_xyops_job_links_on_incident_id"
    t.index ["role"], name: "index_xyops_job_links_on_role"
    t.index ["shard_id"], name: "index_xyops_job_links_on_shard_id"
    t.index ["xyops_alert_id"], name: "index_xyops_job_links_on_xyops_alert_id"
    t.index ["xyops_snapshot_id"], name: "index_xyops_job_links_on_xyops_snapshot_id"
    t.index ["xyops_workflow_run_id"], name: "index_xyops_job_links_on_xyops_workflow_run_id"
  end

  create_table "xyops_snapshots", force: :cascade do |t|
    t.bigint "xyops_connection_id", null: false
    t.string "server_id", null: false
    t.datetime "captured_at", null: false
    t.decimal "cpu_pct", precision: 5, scale: 2
    t.decimal "mem_pct", precision: 5, scale: 2
    t.decimal "disk_pct", precision: 5, scale: 2
    t.integer "redis_latency_ms"
    t.integer "queue_depth"
    t.string "network_status", default: "ok"
    t.jsonb "processes", default: [], null: false
    t.jsonb "network", default: {}, null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.string "server_name"
    t.decimal "cpu_percent", precision: 5, scale: 2
    t.decimal "memory_percent", precision: 5, scale: 2
    t.string "network_summary"
    t.jsonb "process_summary", default: {}
    t.jsonb "metadata", default: {}
    t.index ["captured_at"], name: "index_xyops_snapshots_on_captured_at"
    t.index ["external_id"], name: "index_xyops_snapshots_on_external_id"
    t.index ["server_id"], name: "index_xyops_snapshots_on_server_id"
    t.index ["xyops_connection_id"], name: "index_xyops_snapshots_on_xyops_connection_id"
  end

  create_table "xyops_workflow_runs", force: :cascade do |t|
    t.bigint "xyops_workflow_id", null: false
    t.string "external_id", null: false
    t.string "status", default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "exit_code"
    t.string "server_id"
    t.text "logs_summary"
    t.jsonb "context", default: {}, null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "workflow_name"
    t.string "failed_job_name"
    t.string "server_name"
    t.jsonb "metadata", default: {}
    t.index ["server_id"], name: "index_xyops_workflow_runs_on_server_id"
    t.index ["started_at"], name: "index_xyops_workflow_runs_on_started_at"
    t.index ["status"], name: "index_xyops_workflow_runs_on_status"
    t.index ["workflow_name"], name: "index_xyops_workflow_runs_on_workflow_name"
    t.index ["xyops_workflow_id", "external_id"], name: "idx_xyops_runs_wf_ext", unique: true
    t.index ["xyops_workflow_id"], name: "index_xyops_workflow_runs_on_xyops_workflow_id"
  end

  create_table "xyops_workflows", force: :cascade do |t|
    t.bigint "xyops_connection_id", null: false
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "category"
    t.string "status", default: "active"
    t.datetime "last_run_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_xyops_workflows_on_name"
    t.index ["xyops_connection_id", "external_id"], name: "idx_xyops_workflows_conn_ext", unique: true
    t.index ["xyops_connection_id"], name: "index_xyops_workflows_on_xyops_connection_id"
  end

  add_foreign_key "agent_executions", "incidents"
  add_foreign_key "agent_executions", "shards"
  add_foreign_key "audit_logs", "shards"
  add_foreign_key "error_budgets", "shards"
  add_foreign_key "incidents", "shards"
  add_foreign_key "job_stats", "shards"
  add_foreign_key "xyops_alerts", "xyops_connections", on_delete: :cascade
  add_foreign_key "xyops_alerts", "xyops_workflow_runs", on_delete: :nullify
  add_foreign_key "xyops_job_links", "agent_executions", on_delete: :nullify
  add_foreign_key "xyops_job_links", "incidents", on_delete: :cascade
  add_foreign_key "xyops_snapshots", "xyops_connections", on_delete: :cascade
  add_foreign_key "xyops_workflow_runs", "xyops_workflows", on_delete: :cascade
  add_foreign_key "xyops_workflows", "xyops_connections", on_delete: :cascade
end
