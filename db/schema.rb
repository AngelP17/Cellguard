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

ActiveRecord::Schema[7.1].define(version: 2024_02_17_000003) do
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

  add_foreign_key "agent_executions", "incidents"
  add_foreign_key "agent_executions", "shards"
  add_foreign_key "audit_logs", "shards"
  add_foreign_key "error_budgets", "shards"
  add_foreign_key "incidents", "shards"
  add_foreign_key "job_stats", "shards"
end
