module ClayText
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

  def self.process!(body)
    htmlescape_rules = {
      "&" => "&amp;",
      "\"" => "&quot;",
      "'" => "&#39;",
      "<" => "&lt;",
      ">" => "&gt;"
    }.freeze

    paragraph_types = [:plain, :emailquote, :codeblock, :header, :footer]
    paragraph_rules = {
      Proc.new { |line| line.start_with? "&gt; " } => lambda { |paragraph|
        paragraph.type = :emailquote },
      Proc.new { |line| line.start_with? "    " } => lambda { |paragraph|
        paragraph.type = :codeblock },
      Proc.new { |line| /^\[\d+\]: / =~ line } => lambda { |paragraph|
        paragraph.content.gsub!(%r{^(\[\d+\]:) (.*://(.*))}) {
          "#{$1} <a href=\"#{$2}\">#{$3[0, 64]}#{%{...} if $3.length > 67}</a>"
        }
        paragraph.type = :footer
      }
    }.freeze

    # First, htmlescape the body text
    body.gsub!(/[&"'<>]/, htmlescape_rules)

    paragraphs = []
    body.split("\n\n").each { |content|
      paragraphs << Paragraph.new(content)
    }

    paragraphs[0].first = true
    if paragraphs[0].content.start_with? "(" and
        paragraphs[0].content.end_with? ")"
      paragraphs[0].type = :header
    end

    # Paragraph-level processing
    paragraphs.each { |paragraph|
      paragraph_rules.each { |proc_match, lambda_cb|
        if paragraph.content.lines.all? &proc_match
          lambda_cb.call paragraph
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
