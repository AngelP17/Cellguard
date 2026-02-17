# frozen_string_literal: true

class AgentRunJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 1

  def perform(agent_name, shard_name)
    AgentScheduler.run_agent_on_shard(agent_name, shard_name)
  rescue StandardError => e
    Rails.logger.error "[AgentRunJob] agent=#{agent_name} shard=#{shard_name} failed: #{e.message}"
    raise
  end
end
