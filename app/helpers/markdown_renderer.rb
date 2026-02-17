require "redcarpet"

module MarkdownRenderer
  def render_markdown(md)
    renderer = Redcarpet::Render::HTML.new(with_toc_data: true, hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, autolink: true)
    markdown.render(md).html_safe
  end
end
