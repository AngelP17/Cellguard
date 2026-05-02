# frozen_string_literal: true

module Api
  class IncidentsController < ApplicationController
    protect_from_forgery with: :null_session

    def acknowledge
      incident = Incident.find(params[:id])
      incident.update!(status: "acknowledged")
      AuditLog.create!(
        shard: incident.shard,
        actor: params[:actor].presence || "operator",
        action: "incident_acknowledged",
        justification: "Incident #{incident.id} acknowledged",
        metadata: { incident_id: incident.id, previous_status: incident.status_before_last_save }
      )
      render json: { status: "acknowledged", incident: incident.as_json }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "not_found" }, status: :not_found
    end

    def resolve
      incident = Incident.find(params[:id])
      incident.update!(status: "resolved")
      AuditLog.create!(
        shard: incident.shard,
        actor: params[:actor].presence || "operator",
        action: "incident_resolved",
        justification: "Incident #{incident.id} resolved",
        metadata: { incident_id: incident.id, previous_status: incident.status_before_last_save }
      )
      render json: { status: "resolved", incident: incident.as_json }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "not_found" }, status: :not_found
    end

    def escalate
      incident = Incident.find(params[:id])
      incident.update!(status: "escalated")
      AuditLog.create!(
        shard: incident.shard,
        actor: params[:actor].presence || "operator",
        action: "incident_escalated",
        justification: params[:reason].presence || "Incident #{incident.id} escalated",
        metadata: { incident_id: incident.id, previous_status: incident.status_before_last_save }
      )
      render json: { status: "escalated", incident: incident.as_json }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "not_found" }, status: :not_found
    end

    def note
      incident = Incident.find(params[:id])
      note_text = params[:note].to_s.strip
      return render json: { error: "note_required" }, status: :bad_request if note_text.empty?

      context = incident.context || {}
      notes = Array(context["notes"])
      notes << {
        text: note_text,
        actor: params[:actor].presence || "operator",
        created_at: Time.current.iso8601
      }
      context["notes"] = notes
      incident.update!(context: context)

      render json: { status: "note_added", incident: incident.as_json }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "not_found" }, status: :not_found
    end
  end
end
