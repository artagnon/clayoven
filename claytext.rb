class Paragraph
  attr_accessor :content, :exclude

  def initialize(content)
    @content = content
    @exclude = false
  end
end

class ClayText
  def self.mark_emailquote!(content)
    content = "<span class=\"emailquote\">#{content}</span>"
  end

  def self.mark_codeblock!(content)
    content = "<span class=\"codeblock\">#{content}</span>"
  end

  def self.anchor_footerlinks!(footer)
    footer.gsub!(%r{^(\[\d+\]:) (.*://(.*))}, '\1 <a href="\2">\3</a>')
  end

  def self.process(body)
    puts "DBG: body"
    htmlescape_rules = {
      "&" => "&amp;",
      "\"" => "&quot;",
      "'" => "&apos;",
      "<" => "&lt;",
      ">" => "&gt;"
    }.freeze

    paragraph_rules = {
      Proc.new { |line| line.start_with? "> " } => method(:mark_emailquote!),
      Proc.new { |line| line.start_with? "    " } => method(:mark_codeblock!),
      Proc.new { |line| /^\[\d+\]: / =~ line } => method(:anchor_footerlinks!)
    }.freeze

    body_rules = {
      /(\[\d+\])/ => '<span class="linkref">\1</span>'
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
          callback.call paragraph.content
          paragraph.exclude = true
        end
      }
    }

    # Body-level processing
    paragraphs.select(&:exclude).each { |paragraph|
      paragraph.content.gsub! /[(\[\d+\])]/, body_rules
    }

    puts "<pre>#{paragraphs.map(&:content).join("\n\n")}</pre>"
  end
end

def main
  ClayText.process(IO.read("colophon:claytext"))
end

main
