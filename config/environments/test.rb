require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.active_support.deprecation = :stderr
  config.action_dispatch.show_exceptions = false
  config.action_cable.disable_request_forgery_protection = true
  config.action_controller.allow_forgery_protection = false
end
