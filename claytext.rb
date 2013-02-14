class Paragraph
  attr_accessor :content

  def initialize(content)
    @content = content
  end
end

class ClayText
  def self.mark_emailquote(content)
    "<span class=\"emailquote\">#{content}</span>"
  end

  def self.mark_codeblock(content)
    "<span class=\"codeblock\">#{content}</span>"
  end

  def self.anchor_footerlinks(footer)
    footer.gsub(%r{^(\[\d+\]:) (.*://(.*))}, '\1 <a href="\2">\3</a>')
  end

  def self.process(body)
    htmlescape_rules = {
      "&" => "&amp;",
      "\"" => "&quot;",
      "'" => "&apos;",
      "<" => "&lt;",
      ">" => "&gt;"
    }.freeze

    paragraph_rules = {
      Proc.new { |line| line.start_with? "&gt; " } => method(:mark_emailquote),
      Proc.new { |line| line.start_with? "    " } => method(:mark_codeblock),
      Proc.new { |line| /^\[\d+\]: / =~ line } => method(:anchor_footerlinks)
    }.freeze

    # First, htmlescape the body text
    body.gsub!(/[&"'<>]/, htmlescape_rules)

    # Paragraph-level processing
    paragraphs = []
    body.split("\n\n").each { |content|
      paragraphs << Paragraph.new(content)
    }
    paragraphs.each { |paragraph|
      paragraph_rules.each { |proc_match, callback|
        if paragraph.content.lines.all? &proc_match
          paragraph.content = callback.call paragraph.content
        end
      }
    }
    "\n<pre>#{paragraphs.map(&:content).join("\n\n")}</pre>\n"
  end
end
