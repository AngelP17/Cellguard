# frozen_string_literal: true

module Api
  class AuditLogsController < ApplicationController
    def index
      shard = Shard.find_by!(name: params.fetch(:shard))
      logs = shard.audit_logs.order(created_at: :desc).limit(50)
      render json: logs.as_json(only: %i[actor action justification metadata created_at])
    end
  end
end
