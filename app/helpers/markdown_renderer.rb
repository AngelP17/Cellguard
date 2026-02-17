require "redcarpet"
require "erb"

module MarkdownRenderer
  class CellGuardHTMLRenderer < Redcarpet::Render::HTML
    def block_code(code, language)
      language = language.to_s.strip.downcase
      escaped = ERB::Util.html_escape(code.to_s)

      if language == "mermaid"
        %(<div class="cg-mermaid"><div class="mermaid">#{escaped}</div></div>)
      else
        klass = language.empty? ? "" : "language-#{ERB::Util.html_escape(language)}"
        %(<pre><code class="#{klass}">#{escaped}</code></pre>)
      end
    end
  end

  def render_markdown(md)
    renderer = CellGuardHTMLRenderer.new(with_toc_data: true, hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true, autolink: true)
    markdown.render(md).html_safe
  end
end
