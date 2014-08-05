module ClayText
  # These are the values that Paragraph.type can take
  PARAGRAPH_TYPES = %i[plain emailquote codeblock indentp ulitem olitem
                       subheading header footer]

  # see: http://php.net/manual/en/function.htmlspecialchars.php
  HTMLESCAPE_RULES = {
    '&' => '&amp;',
    '"' => '&quot;',
    "'" => '&#39;',
    '<' => '&lt;',
    '>' => '&gt;'
  }

  # Key is used to match each line in a paragraph, and value is the
  # lambda that'll act on the matched paragraph.
  PARAGRAPH_LINE_FILTERS = {
    # If all the lines in a paragraph begin with "> ", those five
    # characters ("&gt; ") are stripped from the content, and the
    # paragraph is marked as an :emailquote.
    proc { |line| /^&gt; / =~ line } => lambda do |paragraph|
      paragraph.content = paragraph.content.lines.map { |l| l[5..-1] }.join
      paragraph.type = :emailquote
    end,

    # If all the lines in a paragraph begin with "    ", those four
    # characters are stripped from the content, and the paragraph is
    # marked as an :codeblock,
    proc { |line| line.start_with? "    " } => lambda do |paragraph|
      paragraph.content = paragraph.content.lines.map { |l| l[4..-1] }.join
      paragraph.type = :codeblock
    end,

    # If all the lines in a paragraph begin with "  ", those two
    # characters are stripped from the content, and the paragraph is
    # marked as an :indentp,
    proc { |line| line.start_with? "  " } => lambda do |paragraph|
      paragraph.content = paragraph.content.lines.map { |l| l[2..-1] }.join
      paragraph.type = :indentp
    end,

    # If all the lines in a paragraph begin with '[\d+]: ', the
    # paragraph is marked as :footer.  Also, a regex substitution runs
    # on each line turning every link like http://url-over-33-chars to
    # <a href="http://google.com">30-characters-of-the-li...</a>
    # Also, special case github.com links.
    proc { |line| /^\[\d+\]: / =~ line } => lambda do |paragraph|
      paragraph.type = :footer
      paragraph.content.gsub!(%r{^(\[\d+\]:) (.*://(.*))}) do
        if $3.start_with? 'github.com'
          text = 'gh:' + $3[11, 30]
          trunc_len = 44 # 33 + 11
        else
          text = $3[0, 30]
          trunc_len = 33 # 33 = 30 + "...".size
        end
        "#{$1} <a href=\"#{$2}\">#{text}#{%{...} if $3.length > trunc_len}</a>"
      end
    end
  }

  # Key is just a name given to the lambda that acts on the paragraph
  PARAGRAPH_BLOCK_FILTERS = {
    # Numbered list; first line starts with '\d+. ', and the other
    # lines start with '   ', maintaining indent.  Use paragraph
    # level to convey the li value information.
    olitem: lambda do |paragraph|
      first, rest = paragraph.content.split "\n", 2
      rest = [rest] if rest and not rest.is_a? Enumerable
      if /^(\d+)\. / =~ first
        return if rest and not rest.each { |l| l.start_with? '   ' }
        paragraph.content = paragraph.content.lines.map { |l| l[3..-1] }.join
        paragraph.type = :olitem
        paragraph.level = $1
      end
    end,

    # Bulleted list; first line starts with '- ', and the other lines
    # start with '  ', maintaining indent.
    ulitem: lambda do |paragraph|
      first, rest = paragraph.content.split "\n", 2
      rest = [rest] if rest and not rest.is_a? Enumerable
      if first.start_with? '- '
        return if rest and not rest.each { |l| l.start_with? '  ' }
        paragraph.content = paragraph.content.lines.map { |l| l[2..-1] }.join
        paragraph.type = :ulitem
      end
    end,

    # One trailing whitespace (/ $/) indicates that a line break
    # should be inserted.
    hardbr: lambda { |paragraph|
      paragraph.content.gsub!(/ $/, '<br>')
    }
  }

  # A paragraph of text
  #
  # :content contains its content
  # :type can be one of PARAGRAPH_TYPES
  # :level is an integer which has a type-specific meaning
  class Paragraph
    attr_accessor :content, :type, :level

    def initialize content
      @content = content
      @type = :plain

      # Generate is_*? methods for PARAGRAPH_TYPES
      Paragraph.class_eval do
        ClayText::PARAGRAPH_TYPES.each do |type|
          define_method("is_#{type.to_s}?") { @type == type }
        end
      end
    end

    def format_markdown!
      content.gsub!(/(([^\\]|^))`((.|\n)*?)([^\\])`/, "\\1<code>\\3\\5</code>")
      content.gsub!(/(([^\\]|^))_((.|\n)*?)([^\\])_/, "\\1<em>\\3\\5</em>")
      content.gsub!(/(([^\\]|^))\*((.|\n)*?)([^\\])\*/,
                    "\\1<strong>\\3\\5</strong>")
      content.gsub!('--', '—')
      content.gsub!(/\\`/, "`")
      content.gsub!(/\\_/, "_")
      content.gsub!(/\\\*/, "*")
    end

    def is_first?
      @first
    end
  end

  # Takes a body of claytext, breaks it up into paragraphs, and
  # applies various rules on it.
  #
  # Returns a list of Paragraphs
  def self.process body
    # First, htmlescape the body text
    body.gsub! /[&"'<>]/, ClayText::HTMLESCAPE_RULES

    # Split the body into Paragraphs
    paragraphs = []
    body.split("\n\n").each do |content|
      content.rstrip!
      paragraphs << Paragraph.new(content)
    end

    # Special matching for the first paragraph.  This paragraph will
    # be marked header:
    #
    # (This is a really long first paragraph blah-blah-blah-blah-blah
    # that spans to two lines)
    if paragraphs[0].content.start_with? '(' and
        paragraphs[0].content.end_with? ')'
      paragraphs[0].type = :header
    end

    paragraphs.each do |paragraph|
      # Apply the PARAGRAPH_LINE_FILTERS on all the paragraphs
      ClayText::PARAGRAPH_LINE_FILTERS.each do |proc_match, lambda_cb|
        if paragraph.content.lines.all? &proc_match
          lambda_cb.call paragraph
        end
      end
      ClayText::PARAGRAPH_BLOCK_FILTERS.each do |_, lambda_cb|
        lambda_cb.call paragraph
      end
    end

    paragraphs.each do |paragraph|
      if paragraph.is_plain?
        paragraph.format_markdown!
      end
    end

    # body is the useless version.  If someone is too lazy to use all
    # the paragraphs individually in their template, they can just use
    # this.
    body = paragraphs.map(&:content).join("\n\n")

    paragraphs
  end
end
