# frozen_string_literal: true

module Api
  class IncidentsController < ApplicationController
    include ::Api::StructuredErrors
    include ::Api::RequestAudit
    include ::Api::TokenGuard

    protect_from_forgery with: :null_session

    def acknowledge
      require_admin_token!

      incident = Incident.find(params[:id])
      incident.update!(status: "acknowledged")
      audit_request!(
        action: "incident_acknowledged",
        shard: incident.shard,
        justification: "Incident #{incident.id} acknowledged",
        metadata: { incident_id: incident.id, previous_status: incident.status_before_last_save }
      )
      render json: { status: "acknowledged", incident: incident.as_json }
    end

    def resolve
      require_admin_token!

      incident = Incident.find(params[:id])
      incident.update!(status: "resolved")
      audit_request!(
        action: "incident_resolved",
        shard: incident.shard,
        justification: "Incident #{incident.id} resolved",
        metadata: { incident_id: incident.id, previous_status: incident.status_before_last_save }
      )
      render json: { status: "resolved", incident: incident.as_json }
    end

    def escalate
      require_admin_token!

      incident = Incident.find(params[:id])
      incident.update!(status: "escalated")
      audit_request!(
        action: "incident_escalated",
        shard: incident.shard,
        justification: params[:reason].presence || "Incident #{incident.id} escalated",
        metadata: { incident_id: incident.id, previous_status: incident.status_before_last_save }
      )
      render json: { status: "escalated", incident: incident.as_json }
    end

    def note
      require_admin_token!

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

      audit_request!(
        action: "incident_note_added",
        shard: incident.shard,
        justification: "Note added to incident #{incident.id}",
        metadata: { incident_id: incident.id, note_length: note_text.length }
      )

      render json: { status: "note_added", incident: incident.as_json }
    end
  end
end
