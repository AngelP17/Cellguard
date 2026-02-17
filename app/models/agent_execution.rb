# frozen_string_literal: true

class AgentExecution < ApplicationRecord
  belongs_to :shard, optional: true
  belongs_to :incident, optional: true

  enum :status, {
    running: 0,
    completed: 1,
    failed: 2
  }, default: :running

  scope :recent, -> { order(created_at: :desc) }
  scope :for_agent, ->(agent_name) { where(agent_name: agent_name) }
  scope :today, -> { where(created_at: Time.current.beginning_of_day..) }

  def self.start!(agent_name, shard, incident: nil)
    create!(
      agent_name: agent_name,
      shard: shard,
      incident: incident,
      status: :running,
      started_at: Time.current,
      action_details: []
    )
  end

  def complete!(result_payload)
    update!(
      status: :completed,
      result: result_payload,
      completed_at: Time.current
    )
  end

  def fail!(error_message)
    update!(
      status: :failed,
      error_message: error_message,
      completed_at: Time.current
    )
  end

  def duration_ms
    return nil if started_at.nil?

    ended_at = completed_at || Time.current
    ((ended_at - started_at) * 1000).round
  end

  def description
    if action_taken.present?
      action_taken.to_s.humanize
    elsif failed?
      "Agent run failed"
    else
      "Agent run"
    end
  end
end
