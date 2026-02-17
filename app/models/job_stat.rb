class JobStat < ApplicationRecord
  belongs_to :shard

  validates :queue_namespace, :period_start, :period_end, presence: true
  validates :job_count, :error_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
