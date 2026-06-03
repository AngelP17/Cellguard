# frozen_string_literal: true

module Xyops
  # Xyops::SnapshotImporter
  # Pulls server snapshots at key moments (gate lock, incident creation, before remediation)
  # and links them so the audit trail can answer "what was the machine state?"
  class SnapshotImporter
    def self.capture_and_link!(server_id:, shard_name: "shard-default", context: {})
      snap = Xyops::Client.new.capture_snapshot(server_id: server_id, context: context)
      # The simulator already wrote the XyopsSnapshot row. We just return the id for linking.
      snap
    end
  end
end
