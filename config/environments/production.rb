require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.require_master_key = false
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))
  config.active_job.queue_adapter = :sidekiq
  config.action_cable.url = ENV["ACTION_CABLE_URL"] if ENV["ACTION_CABLE_URL"].present?
  config.action_cable.allowed_request_origins = [/.*/]
  config.force_ssl = false
end
