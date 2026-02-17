# frozen_string_literal: true

class CreateAgentConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_configs do |t|
      t.string :key, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :agent_configs, :key, unique: true
  end
end
