class Paragraph
  attr_accessor :content, :first, :type

  def initialize(content)
    @content = content
    @first = false
    @type = :plain
  end

  def is_first?
    @first
  end
end

class ClayText
  def self.mark_emailquote!(paragraph)
    paragraph.type = :emailquote
  end

  def self.mark_codeblock!(paragraph)
    paragraph.type = :codeblock
  end

  def self.anchor_footerlinks!(paragraph)
    paragraph.content.gsub!(%r{^(\[\d+\]:) (.*://(.*))}) {
      "#{$1} <a href=\"#{$2}\">#{$3[0, 64]}#{%{...} if $3.length > 67}</a>"
    }
    paragraph.type = :footer
  end

  def self.process!(body)
    htmlescape_rules = {
      "&" => "&amp;",
      "\"" => "&quot;",
      "'" => "&#39;",
      "<" => "&lt;",
      ">" => "&gt;"
    }.freeze

    paragraph_types = [:plain, :emailquote, :codeblock, :footer]
    paragraph_rules = {
      Proc.new { |line| line.start_with? "&gt; " } => method(:mark_emailquote!),
      Proc.new { |line| line.start_with? "    " } => method(:mark_codeblock!),
      Proc.new { |line| /^\[\d+\]: / =~ line } => method(:anchor_footerlinks!)
    }.freeze

    # First, htmlescape the body text
    body.gsub!(/[&"'<>]/, htmlescape_rules)

    # Paragraph-level processing
    paragraphs = []
    body.split("\n\n").each { |content|
      paragraphs << Paragraph.new(content)
    }
    paragraphs[0].first = true
    paragraphs.each { |paragraph|
      paragraph_rules.each { |proc_match, callback|
        if paragraph.content.lines.all? &proc_match
          callback.call paragraph
        end
      }
    }

    # Generate is_*? methods for Paragraph
    Paragraph.class_eval {
      paragraph_types.each { |type|
        define_method("is_#{type.to_s}?") { @type == type }
      }
    }

    body = paragraphs.map(&:content).join("\n\n")
    paragraphs
  end
end
