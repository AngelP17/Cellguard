# frozen_string_literal: true

require "shellwords"

# Service wrapper for chaos engineering operations
# Used by agents to safely execute chaos operations
class ChaosService
  def initialize(shard)
    @shard = shard
  end

  def execute(operation, params = {})
    case operation
    when :partition
      execute_partition(params)
    when :degrade
      execute_degrade(params)
    else
      { error: "Unknown operation: #{operation}" }
    end
  end

  def heal
    results = {
      tc_heal: heal_tc,
      docker_heal: heal_docker
    }

    results
  end

  private

  def execute_partition(params)
    mode = params[:mode] || "docker"
    duration = params[:duration_seconds] || 20

    case mode
    when "docker"
      partition_docker(duration)
    when "tc"
      degrade_tc(params)
    else
      { error: "Unknown mode: #{mode}" }
    end
  end

  def execute_degrade(params)
    degrade_tc(params)
  end

  def partition_docker(duration_seconds)
    redis_container = ENV.fetch("REDIS_CONTAINER", "sidekiq-cellguard-redis-1")
    network = ENV.fetch("DOCKER_NETWORK", "infrastructure_internal_grid")

    # Disconnect
    cmd = "docker network disconnect #{Shellwords.escape(network)} #{Shellwords.escape(redis_container)}"
    result = system(cmd)

    # Schedule reconnect
    fork do
      sleep duration_seconds
      system("docker network connect #{Shellwords.escape(network)} #{Shellwords.escape(redis_container)}")
    end

    { 
      operation: :partition_docker,
      status: result ? :success : :failed,
      duration: duration_seconds,
      auto_heal_scheduled: true
    }
  end

  def degrade_tc(params)
    iface = ENV.fetch("TC_IFACE", "eth0")
    delay = params[:delay_ms] || 250
    loss = params[:loss_percent] || 5
    duration = params[:duration_seconds] || 20

    # Add latency/loss
    cmd = "sudo tc qdisc add dev #{Shellwords.escape(iface)} root netem delay #{delay}ms loss #{loss}%"
    result = system(cmd)

    # Schedule cleanup
    fork do
      sleep duration
      system("sudo tc qdisc del dev #{Shellwords.escape(iface)} root netem")
    end

    {
      operation: :degrade_tc,
      status: result ? :success : :failed,
      delay_ms: delay,
      loss_percent: loss,
      duration: duration,
      auto_heal_scheduled: true
    }
  end

  def heal_tc
    iface = ENV.fetch("TC_IFACE", "eth0")
    result = system("sudo tc qdisc del dev #{Shellwords.escape(iface)} root netem 2>/dev/null")
    
    { operation: :heal_tc, success: result }
  end

  def heal_docker
    redis_container = ENV.fetch("REDIS_CONTAINER", "sidekiq-cellguard-redis-1")
    network = ENV.fetch("DOCKER_NETWORK", "infrastructure_internal_grid")
    
    result = system("docker network connect #{Shellwords.escape(network)} #{Shellwords.escape(redis_container)} 2>/dev/null")
    
    { operation: :heal_docker, success: result }
  end
end
