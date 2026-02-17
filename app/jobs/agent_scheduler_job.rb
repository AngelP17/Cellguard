# frozen_string_literal: true

class AgentSchedulerJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 1

  def perform
    AgentScheduler.run_all_parallel
  end
end
