require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.active_storage.service = :local if config.respond_to?(:active_storage)
  config.action_cable.disable_request_forgery_protection = true
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.assets.quiet = true if config.respond_to?(:assets)
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"
end
