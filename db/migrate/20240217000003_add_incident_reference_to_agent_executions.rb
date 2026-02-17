# frozen_string_literal: true

class AddIncidentReferenceToAgentExecutions < ActiveRecord::Migration[7.1]
  def change
    add_reference :agent_executions, :incident, foreign_key: true, null: true
  end
end
