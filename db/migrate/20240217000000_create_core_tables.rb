# frozen_string_literal: true

class CreateCoreTables < ActiveRecord::Migration[7.1]
  def change
    create_table :shards do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :shards, :name, unique: true

    create_table :error_budgets do |t|
      t.references :shard, null: false, foreign_key: true
      t.decimal :slo_target, precision: 8, scale: 5, default: 0.999, null: false
      t.integer :window_days, default: 30, null: false
      t.datetime :window_start, null: false
      t.decimal :budget_consumed, precision: 12, scale: 8, default: 0, null: false
      t.decimal :budget_remaining, precision: 12, scale: 8, default: 1, null: false
      t.decimal :current_burn_rate, precision: 10, scale: 4, default: 0, null: false
      t.boolean :release_gate_open, default: true, null: false
      t.datetime :evaluated_at
      t.datetime :violation_started_at

      t.timestamps
    end
    add_index :error_budgets, :evaluated_at

    create_table :job_stats do |t|
      t.references :shard, null: false, foreign_key: true
      t.string :queue_namespace, null: false
      t.datetime :period_start, null: false
      t.datetime :period_end, null: false
      t.integer :job_count, default: 0, null: false
      t.integer :error_count, default: 0, null: false
      t.integer :latency_p95_ms, default: 0, null: false
      t.jsonb :meta, default: {}, null: false

      t.timestamps
    end
    add_index :job_stats, [:shard_id, :queue_namespace, :period_start, :period_end], name: "idx_job_stats_dedupe", unique: true
    add_index :job_stats, :period_end

    create_table :incidents do |t|
      t.references :shard, null: false, foreign_key: true
      t.string :title, null: false
      t.string :severity_label, null: false
      t.string :team_label
      t.string :service_label
      t.string :status, default: "active", null: false
      t.jsonb :context, default: {}, null: false

      t.timestamps
    end
    add_index :incidents, :status
    add_index :incidents, :created_at

    create_table :audit_logs do |t|
      t.references :shard, null: false, foreign_key: true
      t.string :actor, null: false
      t.string :action, null: false
      t.text :justification, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end
    add_index :audit_logs, :created_at
    add_index :audit_logs, :action
  end
end
