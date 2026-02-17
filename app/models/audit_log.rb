class AuditLog < ApplicationRecord
  belongs_to :shard

  validates :actor, :action, :justification, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_actor, ->(actor) { where(actor: actor) }
end
