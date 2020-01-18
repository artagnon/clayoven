module ClayText
  # These are the values that Paragraph.type can take
  PARAGRAPH_TYPES = %i[plain ulitems olitems subheading blurb footer codeblock images horizrule mathjax].freeze

  HTMLESCAPE_RULES = {
    "&" => "&amp;",
    "<" => "&lt;",
    ">" => "&gt;",
  }.freeze

  ROMAN_NUMERALS = {
    10 => "x",
    9 => "ix",
    5 => "v",
    4 => "iv",
    1 => "i",
  }.freeze

  def self.to_arabic(str)
    result = 0
    ROMAN_NUMERALS.values.each do |roman|
      while str.start_with?(roman)
        result += ROMAN_NUMERALS.invert[roman]
        str = str.slice(roman.length, str.length)
      end
    end
    result
  end

  # Key is used to match each line in a paragraph, and value is the
  # lambda that'll act on the matched paragraph.
  PARAGRAPH_LINE_FILTERS = {
    # If all the lines in a paragraph begin with "\d+\. ", those
    # characters are stripped from the content, and the paragraph is
    # marked as an :olitems,
    /^([0-9]+)\. / => lambda do |paragraph, lines, regex|
      match = lines.first.match(regex)[1]
      lines.map! { |k| k.gsub(regex, "") }
      paragraph.type = :olitems
      paragraph.start = match if match
    end,

    # The Roman-numeral version of ol
    /^\(([ivx]+)\) / => lambda do |paragraph, lines, regex|
      match = lines.first.match(regex)[1]
      lines.map! { |k| k.gsub(regex, "") }
      paragraph.type = :olitems
      paragraph.prop = :i
      paragraph.start = to_arabic(match) if match
    end,

    # The alphabetic version of ol
    /^\(([a-z])\) / => lambda do |paragraph, lines, regex|
      match = lines.first.match(regex)[1]
      lines.map! { |k| k.gsub(regex, "") }
      paragraph.type = :olitems
      paragraph.prop = :a
      paragraph.start = match.ord - "a".ord + 1 if match
    end,

    # If all the lines in a paragraph begin with "- ", those
    # characters are stripped from the content, and the paragraph is
    # marked as an :ulitems.
    /^- / => lambda do |paragraph, lines, regex|
      lines.map! { |k| k.gsub(regex, "") }
      paragraph.type = :ulitems
    end,

    # If the paragraph has exactly one line prefixed with a '# ',
    # it is put into the :subheading type.
    /^# / => lambda do |paragraph, lines, regex|
      lines.map! { |k| k.gsub(regex, "") }
      paragraph.type = :subheading
      # See RFC 3986, reserved characters
      paragraph.bookmark = lines.first.downcase
                                .tr('!*\'();:@&=+$,/?#[]', "")
                                .gsub('\\', "").tr("{", "-").tr("}", "")
                                .tr(" ", "-")
    end,

    # If all the lines in a paragraph begin with '[\d+]: ', the
    # paragraph is marked as :footer.
    /^\[\^\d+\]: / => lambda do |paragraph, _, _|
      paragraph.type = :footer
    end,
  }.freeze

  # Start and end markers, making it easy to write commutative diagrams
  XYMATRIX_START = <<-'EOF'
  \begin{xy}
  \xymatrix{
  EOF
  XYMATRIX_END = <<-'EOF'
  }
  \end{xy}
  EOF

  PARAGRAPH_START_END_FILTERS = {
    # Strip out ... and ... for blurbs
    ["...", "..."] => lambda do |p|
      p.contents = p.contents[1..-2]
      p.type = :blurb
    end,
    # Strip out [[ and ]] for codeblocks
    ["[[", "]]"] => lambda do |p|
      p.contents = p.contents[1..-2]
      p.type = :codeblock
    end,
    # Strip out << and >> for images
    ["<<", ">>"] => lambda do |p|
      p.contents = p.contents[1..-2]
      p.type = :images
    end,
    # Horizontal rule
    ["--", "--"] => ->(p) { p.type = :horizrule },
    # MathJaX
    ["$$", "$$"] => ->(p) { p.type = :mathjax },
    # Writing commutative diagrams using xypic
    ["{{", "}}"] => lambda do |p|
      p.contents = ["$$", XYMATRIX_START] + p.contents[1..-2] + [XYMATRIX_END, "$$"]
      p.type = :mathjax
    end,
    # htmlescape everything else
    [] => ->(p) { p.contents.each { |l| l.gsub!(/[<>&]/, ClayText::HTMLESCAPE_RULES) } },
  }.freeze

  # A paragraph of text
  #
  # :content contains its content
  # :type can be one of PARAGRAPH_TYPES
  # :level is an integer which has a type-specific meaning
  class Paragraph
    attr_accessor :contents, :type, :prop, :start, :bookmark

    def initialize(contents)
      @contents = contents
      @type = :plain
      @prop = :none

      # Generate is_*? methods on PARAGRAPH_TYPES
      Paragraph.class_eval do
        ClayText::PARAGRAPH_TYPES.each do |type|
          define_method("is_#{type}?") { @type == type }
        end
      end
    end

    def start?(delim) @contents.first.start_with? delim end
    def end?(delim) @contents.last.end_with? delim end
    def sized?; !@contents.empty? end
  end

  def self.apply_start_end_filters!(paragraphs)
    paragraphs.select(&:sized?).each do |paragraph|
      # For codeblocks [[ and MathJaX blocks \[
      PARAGRAPH_START_END_FILTERS.each do |delim, lambda_cb|
        # The last delim is an empty array, whose lambda specifies htmlescape
        if delim.empty? || (paragraph.start?(delim.first) && paragraph.end?(delim.last))
          lambda_cb.call paragraph
          break
        end
      end
    end
  end

  def self.apply_line_filters!(paragraphs)
    paragraphs.each do |paragraph|
      # Apply the PARAGRAPH_LINE_FILTERS on all the paragraphs
      ClayText::PARAGRAPH_LINE_FILTERS.each do |regex, lambda_cb|
        if paragraph.contents.first && paragraph.contents.all?(regex)
          lambda_cb.call paragraph, paragraph.contents, regex
        end
      end
    end
  end

  # Takes a body of claytext, breaks it up into paragraphs, and
  # applies various rules on it.
  #
  # Returns a list of Paragraphs
  def self.process(body)
    # Split the body into Paragraphs
    paragraphs = []
    body.split("\n\n").each do |content|
      paragraphs << Paragraph.new(content.lines.map!(&:rstrip))
    end

    apply_start_end_filters! paragraphs
    apply_line_filters! paragraphs
    paragraphs
  end
end
