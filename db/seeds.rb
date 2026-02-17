Shard.find_or_create_by!(name: "shard-default") do |s|
  s.build_error_budget(
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

puts "Seeded shard-default + initial error budget"
