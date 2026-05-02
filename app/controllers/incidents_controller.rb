class IncidentsController < ApplicationController
  def index
    @incidents = Incident.order(created_at: :desc).limit(50)

    # Calculate real MTTA and MTTR from incident data
    recent_incidents = Incident.where(created_at: 30.days.ago..Time.current)
    resolved = recent_incidents.where(status: "resolved")

    # MTTR: mean time from created to updated (resolution)
    mttr_durations = resolved.map do |i|
      next if i.updated_at.blank? || i.created_at.blank?
      ((i.updated_at - i.created_at) / 60.0).round(1)
    end.compact

    @mttr_label = if mttr_durations.any?
      avg = (mttr_durations.sum / mttr_durations.size).round(1)
      "#{avg} min"
    else
      "N/A"
    end

    # MTTA: mean time from created to acknowledged (approximate using updated_at for now)
    acknowledged = recent_incidents.where(status: ["acknowledged", "resolved", "escalated"])
    mtta_durations = acknowledged.map do |i|
      next if i.updated_at.blank? || i.created_at.blank?
      ((i.updated_at - i.created_at) / 60.0).round(1)
    end.compact

    @mtta_label = if mtta_durations.any?
      avg = (mtta_durations.sum / mtta_durations.size).round(1)
      "#{avg} min"
    else
      "N/A"
    end
  end
end
