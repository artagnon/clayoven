# The fenced and line transforms for Claytext
module Clayoven::Claytext::Transforms
  # Key is used to match each line in a `Paragraph`, and value is the
  # lambda that'll act on the matched `Paragraph`.
  LINE = {
    # If all the lines in a paragraph begin with "\d+\. ", those
    # characters are stripped from the content, and the paragraph is
    # marked as an :olitems,
    /^([0-9]+)\. / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ''
      paragraph.type = :olitems
      paragraph.olstart = match[1] if match
    end,

    # The Roman-numeral version of ol
    /^\(([ivx]+)\) / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ''
      paragraph.type = :olitems
      paragraph.prop = :i
      paragraph.olstart = Util.to_arabic(match[1]) if match
    end,

    # The alphabetic version of ol
    /^\(([a-z])\) / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ''
      paragraph.type = :olitems
      paragraph.prop = :a
      paragraph.olstart = match[1].ord - 'a'.ord + 1 if match
    end,

    # Exercise blocks
    /^(\+|§) / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ''
      paragraph.type = :exercise
    end,

    # Extending exercise blocks by indenting them
    /^- / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ''
      paragraph.type = :indent
    end,

    # If the paragraph has exactly one line prefixed with hashes,
    # it is put into the :subheading type.
    /^(#+) / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ''
      paragraph.type = :subheading
      paragraph.prop = match[1].length
      # See RFC 3986, reserved characters
      paragraph.bookmark = paragraph.downcase
                                    .tr('!*\'();:@&=+$,/?#[]', '')
                                    .gsub('\\', '').tr('{', '-').tr('}', '')
                                    .tr(' ', '-')
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
    /^(\*|†|‡|§|¶) / => lambda do |paragraph, _|
      paragraph.type = :footer
    end
  }.freeze

  # Start and end markers, making it easy to write commutative diagrams
  XYMATRIX_START = <<-'EOF'.freeze
  \begin{xy}
  \xymatrix{
  EOF
  XYMATRIX_END = <<-'EOF'.freeze
  }
  \end{xy}
  EOF

  # Key is used to starting and ending fences in a `Paragraph`, and value is the
  # lambda that'll act on the matched `Paragraph`.
  FENCED = {
    [/\A\.\.\.$/, /^\.\.\.\z/] => ->(p, _, _) { p.type = :blurb },
    [/\A```(\w*)$/, /^```\z/] => lambda { |p, fc, _|
      p.type = :codeblock
      p.prop = if fc.captures[0].empty?
                 :nohighlight
               else fc.captures[0] end
    },
    [/\A<< (\d+)x(\d+)$/, /^>>\z/] => lambda { |p, fc, _|
      p.type = :images
      dims = Struct.new(:width, :height)
      p.prop = dims.new(fc.captures[0], fc.captures[1])
      basepath = Dir.getwd + p.to_s
      if (p.to_s.split("\n").length == 1) && Dir.exist?(basepath)
        p.replace Dir.glob('*.svg', base: basepath).sort_by { |e| e[..-4].to_i }
                     .map { |e| p.to_s + e }.join("\n")
      end
    },

    # MathJaX: put the markers back, since js needs it: $$ ... $$
    [/\A\$\$/, /\$\$\z/] => lambda do |p, _, _|
      p.type = :mathjax
      p.replace ['$$', p.to_s, '$$'].join("\n")
    end,

    # Writing commutative diagrams using xypic: {{ ... }}
    [/\A\{\{$/, /^\}\}\z/] => lambda do |p, _, _|
      p.type = :mathjax
      p.replace ['$$', XYMATRIX_START, p.to_s, XYMATRIX_END, '$$'].join("\n")
    end
  }.freeze
end
