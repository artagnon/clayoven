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
      Proc.new { |line| /^\[\d+\]: / =~ line } => lambda do |paragraph|
        paragraph.content.gsub!(%r{^(\[\d+\]:) (.*://(.*))}) do
          "#{$1} <a href=\"#{$2}\">#{$3[0, 64]}#{%{...} if $3.length > 67}</a>"
        end
        paragraph.type = :footer
      end
    }.freeze

    # First, htmlescape the body text
    body.gsub!(/[&"'<>]/, htmlescape_rules)

    paragraphs = []
    body.split("\n\n").each do |content|
      paragraphs << Paragraph.new(content)
    end

    paragraphs[0].first = true
    if paragraphs[0].content.start_with? "(" and
        paragraphs[0].content.end_with? ")"
      paragraphs[0].type = :header
    end

    # Paragraph-level processing
    paragraphs.each do |paragraph|
      paragraph_rules.each do |proc_match, lambda_cb|
        if paragraph.content.lines.all? &proc_match
          lambda_cb.call paragraph
        end
      end
    end

    # Generate is_*? methods for Paragraph
    Paragraph.class_eval do
      paragraph_types.each do |type|
        define_method("is_#{type.to_s}?") { @type == type }
      end
    end

    body = paragraphs.map(&:content).join("\n\n")
    paragraphs
  end
end
