module ClayText
  # These are the values that Paragraph.type can take
  PARAGRAPH_TYPES = %i[plain ulitems olitems subheading exercise blurb footer codeblock images horizrule mathjax].freeze

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
  PARAGRAPH_LINE_TRANSFORMS = {
    # If all the lines in a paragraph begin with "\d+\. ", those
    # characters are stripped from the content, and the paragraph is
    # marked as an :olitems,
    /^([0-9]+)\. / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ""
      paragraph.type = :olitems
      paragraph.olstart = match[1] if match
    end,

    # The Roman-numeral version of ol
    /^\(([ivx]+)\) / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ""
      paragraph.type = :olitems
      paragraph.prop = :i
      paragraph.olstart = to_arabic(match[1]) if match
    end,

    # The alphabetic version of ol
    /^\(([a-z])\) / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ""
      paragraph.type = :olitems
      paragraph.prop = :a
      paragraph.olstart = match[1].ord - "a".ord + 1 if match
    end,

    # If all the lines in a paragraph begin with "- ", those
    # characters are stripped from the content, and the paragraph is
    # marked as an :ulitems.
    /^- / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ""
      paragraph.type = :ulitems
    end,

    # Shorthand for one-line exercise blocks
    /^\+ / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ""
      paragraph.type = :exercise
    end,

    # If the paragraph has exactly one line prefixed with a '# ',
    # it is put into the :subheading type.
    /^# / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ""
      paragraph.type = :subheading
      # See RFC 3986, reserved characters
      paragraph.bookmark = paragraph.downcase
        .tr('!*\'();:@&=+$,/?#[]', "")
        .gsub('\\', "").tr("{", "-").tr("}", "")
        .tr(" ", "-")
    end,

    # Horizontal line, in a paragraph of its own
    /^--$/ => lambda do |paragraph, _|
      paragraph.type = :horizrule
    end,

    # If all the lines in a paragraph begin with '[\d+]: ', the
    # paragraph is marked as :footer.
    /^\[\^\d+\]: / => lambda do |paragraph, _|
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

  PARAGRAPH_FENCED_TRANSFORMS = {
    ["...", "..."] => ->(p) { p.type = :blurb },
    ["[[", "]]"] => ->(p) { p.type = :codeblock },
    ["<<", ">>"] => ->(p) { p.type = :images },
    ["++", "++"] => ->(p) { p.type = :exercise },

    # MathJaX: put the markers back, since js needs it
    ["$$", "$$"] => lambda do |p|
      p.type = :mathjax
      p.replace ["$$", p.to_s, "$$"].join("\n")
    end,

    # Writing commutative diagrams using xypic
    ["{{", "}}"] => lambda do |p|
      p.type = :mathjax
      p.replace ["$$", XYMATRIX_START, p.to_s, XYMATRIX_END, "$$"].join("\n")
    end,
  }.freeze

  # A paragraph of text
  #
  # :content is a string that contains a fenced block (after merge_fenced!)
  # :type can be one of PARAGRAPH_TYPES
  # :prop is auxiliary type-specific information
  # :olstart is an auxiliary field for list-numbering
  # :bookmark is another auxiliary field that makes sense in :subheading
  # :children stores children paragraph, a field that makes sense in :exercise
  class Paragraph < String
    attr_accessor :type, :prop, :olstart, :bookmark, :children

    def initialize(contents)
      super contents
      @type = :plain
      @prop = :none
      @children = nil

      # Generate is_*? methods on PARAGRAPH_TYPES
      Paragraph.class_eval do
        PARAGRAPH_TYPES.each do |type|
          define_method("is_#{type}?") { @type == type }
        end
      end
    end
  end

  def self.merge_fenced!(arr, first, last)
    matched_blocks = []
    arr.each_with_index do |p, pidx|
      next if not p.start_with? first
      arr[pidx..-1].each_with_index do |q, idx|
        qidx = pidx + idx # the real index
        next if not q.end_with? last
        # strip out the delims at the beginning and end
        p.replace(arr[pidx..qidx].join("\n\n"))
         .gsub!(/((^#{Regexp.quote first}\s*)|(\s*#{Regexp.quote last}$))/, "")
        matched_blocks << p
        arr.slice! pidx + 1, idx
        break
      end
    end
    matched_blocks
  end

  def self.fenced_transforms!(paragraphs)
    # For MathJax, exercises, codeblocks, and other fenced content
    PARAGRAPH_FENCED_TRANSFORMS.each do |delims, lambda_cb|
      blocks = merge_fenced!(paragraphs, delims.first, delims.last)
      blocks.each { |p| lambda_cb.call p }
    end
  end

  def self.line_transforms!(paragraphs)
    paragraphs.each do |p|
      # Apply the PARAGRAPH_LINE_TRANSFORMS on all the paragraphs
      PARAGRAPH_LINE_TRANSFORMS.each do |regex, lambda_cb|
        lambda_cb.call(p, regex) if p.split("\n").all?(regex)
      end
    end
  end

  # Takes a body of claytext, breaks it up into paragraphs, and
  # applies various rules on it.
  #
  # Returns a list of Paragraphs
  def self.process(body)
    # Split the body into Paragraphs
    paragraphs = body.split("\n\n").map { |p| Paragraph.new p.rstrip }

    # merge paragraphs along fences, and do the transforms
    fenced_transforms! paragraphs
    line_transforms! paragraphs

    # at the end of both sets of transforms, htmlescape everything but mathjax and codeblocks
    paragraphs.filter { |p| not(p.is_mathjax? or p.is_codeblock?) }.each do |p|
      p.gsub!(/[<>&]/, ClayText::HTMLESCAPE_RULES)
    end

    # return the final list of paragraphs
    paragraphs
  end
end
