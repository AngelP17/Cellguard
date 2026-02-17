# frozen_string_literal: true

module Api
  # API endpoints for agent management and manual triggering
  class AgentsController < ApplicationController
    protect_from_forgery with: :null_session

    # GET /api/agents/status
    def status
      render json: AgentScheduler.status
    end

    # GET /api/agents/activity
    def activity
      limit = params.fetch(:limit, 20).to_i
      render json: AgentScheduler.recent_activity(limit: limit)
    end

    # POST /api/agents/:name/run
    def run
      agent_name = params.fetch(:name)
      shard_name = params.fetch(:shard, "shard-default")

      result = AgentScheduler.run_agent_on_shard(agent_name, shard_name)
      broadcast_status_update!

      if result
        render json: {
          agent: agent_name,
          shard: shard_name,
          executed: true,
          result: result
        }
      else
        render json: {
          agent: agent_name,
          shard: shard_name,
          executed: false,
          reason: "Agent disabled or shard not found"
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /api/agents/run-all
    def run_all
      async = async_run_all?

      if async
        jobs = AgentScheduler.run_all_parallel
        render json: {
          mode: "async",
          enqueued: jobs.length,
          jobs: jobs
        }
      else
        results = AgentScheduler.run_all
        render json: {
          mode: "sync",
          executed: results.length,
          results: results
        }
      end
    end

    # POST /api/agents/:name/toggle
    def toggle
      agent_name = params.fetch(:name)
      enabled = ActiveModel::Type::Boolean.new.cast(params.fetch(:enabled))

      AgentConfig.toggle!(agent_name, enabled)
      effective_enabled = AgentConfig.enabled?(agent_name)

      ActionCable.server.broadcast("agent_activity", {
        type: "agent_toggled",
        agent: agent_name,
        enabled: effective_enabled
      })
      broadcast_status_update!

      render json: {
        agent: agent_name,
        enabled: effective_enabled
      }
    end

    private

    def async_run_all?
      return true unless params.key?(:async)

      ActiveModel::Type::Boolean.new.cast(params[:async])
    end

    def broadcast_status_update!
      ActionCable.server.broadcast("agent_activity", {
        type: "status_update",
        status: AgentScheduler.status,
        recent_activity: AgentScheduler.recent_activity(limit: 10)
      })
    end
  end
end
