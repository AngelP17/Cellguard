class Incident < ApplicationRecord
  belongs_to :shard
  has_many :agent_executions, dependent: :nullify

  validates :title, :severity_label, presence: true

  scope :active, -> { where(status: ["active", "investigating"]) }
  scope :resolved, -> { where(status: "resolved") }
  scope :recent, -> { order(created_at: :desc) }

  after_create :notify_agents

  private

  def notify_agents
    Agents::IncidentResponseAgent.process_incident(self)
  rescue StandardError => e
    Rails.logger.error "[Incident] Failed to notify agents: #{e.message}"
  end
end
