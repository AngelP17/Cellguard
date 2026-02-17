# frozen_string_literal: true

class AgentConfig < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  ENV_PREFIX = "CELLGUARD_"

  DEFAULTS = {
    "agents_enabled" => "true",
    "agent_execution_interval_seconds" => "60",
    "budget_guard_enabled" => "true",
    "budget_guard_exhaustion_threshold_hours" => "24",
    "budget_guard_critical_burn_rate" => "2.0",
    "budget_guard_critical_remaining" => "0.3",
    "budget_guard_auto_chaos" => "false",
    "chaos_orchestrator_enabled" => "false",
    "chaos_min_interval_hours" => "24",
    "chaos_max_blast_radius" => "shard-default",
    "incident_response_enabled" => "true",
    "incident_auto_runbook_suggestions" => "true",
    "healing_agent_enabled" => "true",
    "healing_auto_recover" => "false",
    "healing_max_retry_attempts" => "3"
  }.freeze

  AGENTS = {
    "budget_guard" => "Monitors error budget burn rate and predicts exhaustion",
    "chaos_orchestrator" => "Intelligently schedules chaos engineering drills",
    "incident_response" => "Auto-generates runbook suggestions for incidents",
    "healing" => "Attempts automatic recovery from detected faults"
  }.freeze

  class << self
    def global_enabled?
      get_bool("agents_enabled")
    end

    def agents
      AGENTS.map do |name, description|
        {
          name: name,
          enabled: enabled?(name),
          description: description,
          recent_executions: AgentExecution.for_agent(name).today.count
        }
      end
    end

    def enabled?(agent_name)
      get_bool(enabled_key(agent_name))
    end

    def toggle!(agent_name, enabled)
      set!(enabled_key(agent_name), enabled.to_s)
    end

    def get_bool(key)
      ActiveModel::Type::Boolean.new.cast(get(key))
    end

    def get_int(key)
      get(key).to_i
    end

    def get_float(key)
      get(key).to_f
    end

    def get(key)
      record_value = find_by(key: key)&.value
      return record_value if record_value.present?

      env_value = ENV[env_key(key)]
      return env_value if env_value.present?

      DEFAULTS.fetch(key, "")
    end

    def set!(key, value)
      record = find_or_initialize_by(key: key)
      record.value = value.to_s
      record.save!
      record
    end

    private

    def env_key(key)
      "#{ENV_PREFIX}#{key.upcase}"
    end

    def enabled_key(agent_name)
      return "healing_agent_enabled" if agent_name.to_s == "healing"

      "#{agent_name}_enabled"
    end
  end
end
