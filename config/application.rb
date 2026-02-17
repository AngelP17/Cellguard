require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Cellguard
  class Application < Rails::Application
    config.load_defaults 7.1
    config.time_zone = "UTC"
    config.active_job.queue_adapter = :sidekiq
    agents_path = Rails.root.join("app/agents").to_s
    app_root_path = Rails.root.join("app").to_s
    config.autoload_paths.delete(agents_path)
    config.eager_load_paths.delete(agents_path)
    config.autoload_paths << app_root_path
    config.eager_load_paths << app_root_path
    config.generators.system_tests = nil
  end
end
