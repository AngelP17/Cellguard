# frozen_string_literal: true

if defined?(Sidekiq) && defined?(Sidekiq::Scheduler)
  Sidekiq.configure_server do |_config|
    schedule_file = Rails.root.join("config", "sidekiq.yml")
    next unless File.exist?(schedule_file)

    raw_config = YAML.load_file(schedule_file)
    schedule = raw_config.dig(:scheduler, :schedule) || raw_config.dig("scheduler", "schedule")
    next if schedule.blank?

    Sidekiq.schedule = schedule
    Sidekiq::Scheduler.reload_schedule!
  end
end
