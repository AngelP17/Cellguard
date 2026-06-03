class IncidentsController < ApplicationController
  def index
    # Ensure demo data exists so the UI never shows empty states
    DemoDataService.ensure_all!

    @incidents = Incident.order(created_at: :desc).limit(50)

    # Calculate real MTTA and MTTR from incident data
    recent_incidents = Incident.where(created_at: 60.days.ago..Time.current)
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
      "No resolutions"
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
      "No acks yet"
    end

    # Attach xyOps evidence for the featured incident (FROM DB models)
    @featured = @incidents.first
    @xyops_evidence = begin
      if @featured && defined?(XyopsJobLink)
        links = XyopsJobLink.for_incident(@featured.id).includes(:workflow_run, :alert, :snapshot).order(created_at: :desc)
        run = links.map(&:xyops_workflow_run).compact.first || XyopsWorkflowRun.order(created_at: :desc).first
        al = links.map(&:xyops_alert).compact.first || XyopsAlert.order(fired_at: :desc).first
        sn = links.map(&:xyops_snapshot).compact.first || XyopsSnapshot.order(captured_at: :desc).first
        if run || al || sn
          {
            workflow: run&.workflow_name || run&.workflow&.name,
            job: run&.failed_job_name || (run&.context || {})["job"],
            server: run&.server_name || run&.server_id || sn&.server_name,
            alert: al&.title,
            snapshot: sn ? { cpu: (sn.cpu_percent || sn.cpu_pct), redis_ms: (sn.redis_latency_ms || 0) } : nil,
            remediation: links.any? { |l| l.role == "remediation" } || run&.status == "succeeded"
          }.compact
        end
      end
    rescue
      nil
    end
  end
end


