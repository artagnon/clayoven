# -*- coding: utf-8 -*-

module ClayText
  # These are the values that Paragraph.type can take
  # PARAGRAPH_TYPES = %i[plain olitems subheading exercise indent blurb footer codeblock images horizrule mathjax].freeze

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

    # Exercise blocks
    /^(\+|§) / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ""
      paragraph.type = :exercise
    end,

    # Extending exercise blocks by indenting them
    /^- / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ""
      paragraph.type = :indent
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
      paragraph.prop = :horizrule
    end,

    # Ellipses hr, in a paragraph of its own
    /^\.\.$/ => lambda do |paragraph, _|
      paragraph.type = :horizrule
      paragraph.prop = :ellipses
    end,

    # If all the lines in a paragraph begin with certain unicode symbols, the
    # paragraph is marked as :footer.
    /^(\*|†|‡|§|||¶) / => lambda do |paragraph, _|
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
    [/\A\.\.\.$/, /^\.\.\.\z/] => ->(p, _, _) { p.type = :blurb },
    [/\A~~$/, /^~~\z/] => ->(p, _, _) { p.type = :codeblock; p.prop = :coq },
    [/\A```(\w+)$/, /^```\z/] => ->(p, fc, _) { p.type = :codeblock; p.prop = fc.captures[0] },
    [/\A<<$/, /^>>\z/] => ->(p, _, _) { p.type = :images },

    # MathJaX: put the markers back, since js needs it
    # Missing $ and ^ markers due to backward-compatibility
    [/\A\$\$/, /\$\$\z/] => lambda do |p, _, _|
      p.type = :mathjax
      p.replace ["$$", p.to_s, "$$"].join("\n")
    end,

    # Writing commutative diagrams using xypic
    [/\A\{\{$/, /^\}\}\z/] => lambda do |p, _, _|
      p.type = :mathjax
      p.replace ["$$", XYMATRIX_START, p.to_s, XYMATRIX_END, "$$"].join("\n")
    end,
  }.freeze

  # A paragraph of text
  #
  # :content is a string that contains a fenced block (after merge_fenced!)
  # :type can be one of PARAGRAPH_TYPES
  # :prop is auxiliary type-specific information (:a is for lettered-lists, :i is for numbered-lists, and :coq is for coq-code)
  # :olstart is an auxiliary field for list-numbering
  # :bookmark is another auxiliary field that makes sense in :subheading
  # :children stores children paragraph, a field that makes sense in :exercise
  class Paragraph < String
    attr_accessor :type, :prop, :olstart, :bookmark, :children

    def initialize(contents)
      super
      @type = :plain
      @prop = :none
      @children = nil
    end
  end

  def self.merge_fenced!(arr, fregex, lregex)
    mb = Struct.new(:block, :fc, :lc)
    matched_blocks = []
    arr.each_with_index do |p, pidx|
      next if not fregex.match p
      arr[pidx..-1].each_with_index do |q, idx|
        qidx = pidx + idx # the real index
        next if not lregex.match q
        # strip out the delims at the beginning and end
        matches = fregex.match(p), lregex.match(q)
        p.replace(arr[pidx..qidx].join("\n\n")).sub!(fregex, "").sub!(lregex, "").strip!
        matched_blocks << mb.new(p, matches[0], matches[1])
        arr.slice! pidx + 1, idx
        break
      end
    end
    matched_blocks
  end

  def self.fenced_transforms!(paragraphs)
    # For MathJax, exercises, codeblocks, and other fenced content
    PARAGRAPH_FENCED_TRANSFORMS.each do |delims, lambda_cb|
      blocks = merge_fenced! paragraphs, delims[0], delims[1]
      blocks.each { |blk| lambda_cb.call blk.block, blk.fc, blk.lc }
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
    paragraphs.filter { |p| not(p.type == :mathjax or p.type == :codeblock) }.each do |p|
      p.gsub!(/[<>&]/, ClayText::HTMLESCAPE_RULES)
    end

    # Insert HTML breaks in :plain paragraphs
    paragraphs.filter { |p| p.type == :plain }.each { |p| p.gsub! /\n/, "<br/>\n" }

    # Insert <{mark, a}> in :plain, :olitems, and :footer paragraphs
    paragraphs.filter { |p| p.type == :plain or p.type == :olitems or p.type == :exercise or p.type == :footer }.each do |p|
      p.gsub! /`([^`]+)`/, '<mark>\1</mark>'
      p.gsub! /\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>'
    end

    paragraphs
  end
end
