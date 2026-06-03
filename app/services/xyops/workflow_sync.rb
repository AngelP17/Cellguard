# frozen_string_literal: true

module Xyops
  # Xyops::WorkflowSync
  # Periodically (or on demand) syncs workflow definitions and recent runs from xyOps into local tables.
  # For the demo this mostly ensures the seed workflows exist and recent runs are queryable.
  class WorkflowSync
    def self.sync!(shard: nil)
      Xyops::Simulator.seed_workflows!
      # In real mode would call client.list_workflows and upsert.
      { synced: XyopsWorkflow.count, at: Time.current }
    end
  end
end
