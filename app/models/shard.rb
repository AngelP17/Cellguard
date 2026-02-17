class Shard < ApplicationRecord
  has_one :error_budget, dependent: :destroy
  has_many :job_stats, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :agent_executions, dependent: :nullify

  validates :name, presence: true, uniqueness: true
end
