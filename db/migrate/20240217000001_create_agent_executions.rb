# frozen_string_literal: true

class CreateAgentExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_executions do |t|
      t.string :agent_name, null: false
      t.references :shard, null: true, foreign_key: true
      t.integer :status, default: 0, null: false
      t.string :action_taken
      t.jsonb :action_details, default: []
      t.jsonb :result
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :agent_executions, :agent_name
    add_index :agent_executions, :status
    add_index :agent_executions, :created_at
    add_index :agent_executions, [:agent_name, :created_at]
  end
end
