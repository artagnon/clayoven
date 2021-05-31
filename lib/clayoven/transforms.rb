# The transforms that act on a Clayoven::Claytext::Paragraph
#
# Extending the syntax of claytext is easy: just add an entry here.
module Clayoven::Claytext::Transforms
  # Line transforms
  #
  # The key is used to match each line in a Clayoven::Claytext::Paragraph, and value is the
  # lambda that'll act on the matched paragraph.
  LINE = {
    # If all the lines in a paragraph begin with "\d+\. ", those
    # characters are stripped from the content, and the paragraph is
    # marked as an :olitems,
    /^([0-9]+)\. / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ''
      paragraph.type = :olitems
      paragraph.olstart = match[1]
    end,

    # The Roman-numeral version of ol
    /^\(([ivx]+)\) / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ''
      paragraph.type = :olitems
      paragraph.prop = :i
      paragraph.olstart = Util.to_arabic(match[1])
    end,

    # The alphabetic version of ol
    /^\(([a-z])\) / => lambda do |paragraph, regex|
      match = paragraph.match regex
      paragraph.gsub! regex, ''
      paragraph.type = :olitems
      paragraph.prop = :a
      paragraph.olstart = match[1].ord - 'a'.ord + 1
    end,

    # Exercise blocks
    /^(\+|§) / => lambda do |paragraph, regex|
      paragraph.gsub! regex, ''
      paragraph.type = :exercise
    end,

    # Indenting a block
    /^  / => lambda do |paragraph, regex|
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

  # Start marker for commutative diagrams, rendered using XyJaX
  XYMATRIX_START = <<-'EOF'.freeze
  \begin{xy}
  \xymatrix{
  EOF

  # End marker for commutative diagrams, rendered using XyJaX
  XYMATRIX_END = <<-'EOF'.freeze
  }
  \end{xy}
  EOF

  # Fenced transforms
  #
  # The key is used to starting and ending fences in a Clayoven::Claytext::Paragraph, and value is the
  # lambda that'll act on the matched paragraph.
  FENCED = {
    # For blurbs
    [/\A\.\.\.$/, /^\.\.\.\z/] => ->(p, _, _) { p.type = :blurb },

    # For codeblocks
    [/\A```(\w*)$/, /^```\z/] => lambda { |p, fc, _|
      p.type = :codeblock
      p.prop = if fc.captures[0].empty?
                 :nohighlight
               else fc.captures[0] end
    },

    # For images and notebooks of svgs
    [/\A<< (\d+)x(\d+)$/, /^>>\z/] => lambda { |p, fc, _|
      p.type = :images
      dims = Struct.new(:width, :height)
      p.prop = dims.new(fc.captures[0], fc.captures[1])
      if (p.split("\n").length == 1) && File.directory?(p)
        p.replace Dir.glob("#{p}/*.svg", base: Clayoven::Git.toplevel)
                     .sort_by { |e| e.split('/')[-1].split('.svg')[0].to_i }.join("\n")
      end
      # Artificially make all paths start with /
      p.replace p.split("\n").map { |e| File.join('/', e) }.join("\n")
    },

    # MathJaX: put the markers back, since js needs it: $$ ... $$
    [/\A\$\$/, /\$\$\z/] => lambda do |p, _, _|
      p.type = :mathjax
      p.replace ['$$', p.to_s, '$$'].join("\n")
    end,

    # Writing commutative diagrams using xypic: {{ ... }}, rendered using XyJaX
    [/\A\{\{$/, /^\}\}\z/] => lambda do |p, _, _|
      p.type = :mathjax
      p.replace ['$$', XYMATRIX_START, p.to_s, XYMATRIX_END, '$$'].join("\n")
    end
  }.freeze
end
