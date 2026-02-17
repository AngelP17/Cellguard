Rails.application.config.to_prepare do
  begin
    next unless ActiveRecord::Base.connection.data_source_exists?("shards")

    shard = Shard.find_or_create_by!(name: "shard-default")

    if shard.error_budget.nil?
      shard.create_error_budget!(
        slo_target: 0.999,
        window_days: 30,
        window_start: Time.current,
        budget_consumed: 0,
        budget_remaining: 1,
        current_burn_rate: 0,
        release_gate_open: true,
        evaluated_at: Time.current
      )
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    nil
  end
end
