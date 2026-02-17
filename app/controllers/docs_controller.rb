class DocsController < ApplicationController
  include MarkdownRenderer

  def runbook
    slug = params.fetch(:slug)
    path = Rails.root.join("docs", "runbooks", "#{slug}.md")
    @slug = slug
    @runbook_slugs = available_runbook_slugs
    @prev_runbook_slug, @next_runbook_slug = previous_and_next_runbooks(slug)
    @incident = load_incident
    @related_runbooks = Array(@incident&.context&.dig("suggested_runbooks"))
    @recent_incidents = Incident.recent.limit(5)
    @recent_audit_logs = AuditLog.recent.limit(5)
    render_doc!(path, title: "Runbook: #{slug}")
  end

  def postmortem
    slug = params.fetch(:slug)
    path = Rails.root.join("docs", "postmortems", "#{slug}.md")
    @slug = slug
    @recent_incidents = Incident.recent.limit(5)
    @recent_audit_logs = AuditLog.recent.limit(5)
    render_doc!(path, title: "Postmortem: #{slug}")
  end

  private

  def render_doc!(path, title:)
    raise ActiveRecord::RecordNotFound unless File.exist?(path)

    @title = title
    @html = render_markdown(File.read(path))
    render "docs/show"
  end

  def available_runbook_slugs
    Dir.glob(Rails.root.join("docs", "runbooks", "*.md"))
      .map { |path| File.basename(path, ".md") }
      .sort
  end

  def previous_and_next_runbooks(slug)
    return [nil, nil] if @runbook_slugs.blank?

    index = @runbook_slugs.index(slug)
    return [nil, nil] unless index

    prev_slug = index.positive? ? @runbook_slugs[index - 1] : nil
    next_slug = index < (@runbook_slugs.length - 1) ? @runbook_slugs[index + 1] : nil
    [prev_slug, next_slug]
  end

  def load_incident
    return nil unless params[:incident_id].present?

    Incident.find_by(id: params[:incident_id])
  end
end
