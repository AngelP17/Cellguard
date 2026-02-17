class DocsController < ApplicationController
  include MarkdownRenderer

  def runbook
    slug = params.fetch(:slug)
    path = Rails.root.join("docs", "runbooks", "#{slug}.md")
    render_doc!(path, title: "Runbook: #{slug}")
  end

  def postmortem
    slug = params.fetch(:slug)
    path = Rails.root.join("docs", "postmortems", "#{slug}.md")
    render_doc!(path, title: "Postmortem: #{slug}")
  end

  private

  def render_doc!(path, title:)
    raise ActiveRecord::RecordNotFound unless File.exist?(path)

    @title = title
    @html = render_markdown(File.read(path))
    render "docs/show"
  end
end
