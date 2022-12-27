require "rouge"

# The transforms that act on a Clayoven::Claytext::Paragraph
#
# Extending the syntax of claytext is easy: just add an entry here.
module Clayoven::Claytext::Transforms
  # Line transforms
  #
  # The key is used to match each line in a Clayoven::Claytext::Paragraph
  # and value is the lambda that'll act on the matched p.
  LINE = {
    # If all the lines in a paragraph begin with "\d+\. ",
    # those characters are stripped from the content,
    # and the paragraph is marked as an :olitems,
    /^([0-9]+)\. / => ->(p, match) do
      p.type = :olitems
      p.olstart = match[1]
    end,
    # The Roman-numeral version of ol
    /^\(([ivx]+)\) / => ->(p, match) do
      p.type = :olitems
      p.prop = :i
      p.olstart = Util.to_arabic match[1]
    end,
    # The alphabetic version of ol
    /^\(([a-z])\) / => ->(p, match) do
      p.type = :olitems
      p.prop = :a
      p.olstart = match[1].ord - "a".ord + 1
    end,
    # The code for :ulitems is much simpler
    /^(\-) / => ->(p, _) { p.type = :ulitems },
    # Exercise blocks
    /^(\+|§) / => ->(p, _) { p.type = :exercise },
    # Subheading: (#|##) ...
    /^(#+) / => ->(p, match) do
      p.type = :subheading
      p.prop = match[1].length
      # See RFC 3986, reserved characters
      p.bookmark =
        p
          .downcase
          .tr('!*\'();:@&=+$,/?#[]', "")
          .gsub('\\', "")
          .tr("{", "-")
          .tr("}", "")
          .tr(" ", "-")
    end,
    # Horizontal line, in a p of its own
    /\A(--)\Z/ => ->(p, _) do
      p.type = :horizrule
      p.prop = :horizrule
    end,
    # Ellipses hr, in a p of its own
    /\A(\.\.)\Z/ => ->(p, _) do
      p.type = :horizrule
      p.prop = :ellipses
    end,
    # Footer, rendered as a ul
    /^(†|‡|§|¶) / => ->(p, _) { p.type = :footer }
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
  # The key is used to starting and ending fences in a Clayoven::Claytext::Paragraph,
  # and value is the lambda that'll act on the matched paragraph.
  FENCED = {
    # Blurbs: '... [...] ...'
    [/\A\.\.\.$/, /^\.\.\.\z/] => ->(p, _, _) { p.type = :blurb },
    # Codeblocks; syntax highlighting with Rouge: ``` .... ```
    [/\A```(\w*)$/, /^```\z/] => ->(p, fc, _) do
      p.type = :codeblock
      if fc.captures[0].empty?
        p.prop = ""
      else
        formatter = Rouge::Formatters::HTML.new()
        lexer = (Util::ROUGE_LEXERS[fc.captures[0]]).new()
        p.replace (formatter.format(lexer.lex p))
        p.prop = Rouge::Themes::Base16::Solarized.mode(:light).render()
      end
    end,
    # Images and notebooks of images: << [dims] ... >>
    [/\A<< (\d+)x(\d+)$/, /^>>\z/] => ->(p, fc, _) do
      p.type = :images
      dims = Struct.new(:width, :height)
      p.prop = dims.new(fc.captures[0], fc.captures[1])

      # Artificially make all paths start with /
      p.replace (p.split("\n").map { |e| File.join("/", e.strip) }.join("\n"))

      # For notebooks of images, all the images must be named [0-9]+.{svg,png,hiec,jpg}
      if (p.split("\n").length == 1) && File.directory?(p[1..])
        p.replace Dir
                    .glob(
                      "#{p[1..]}/*.{svg,png,heic,jpg}",
                      base: Clayoven::Git.toplevel
                    )
                    .sort_by { |e|
                      e.split("/")[-1].split(/\.\w{1-4}$/)[0].to_i
                    }
                    .map { |e| File.join("/", e) }
                    .join("\n")
      end
    end,
    # MathJaX: put the markers back, since js needs it: $$ ... $$
    [/\A\$\$/, /\$\$\z/] => ->(p, _, _) do
      p.type = :mathjax
      p.replace ["$$", p.to_s, "$$"].join("\n")
    end,
    # Writing commutative diagrams using xypic: {{ ... }}, rendered using XyJaX
    [/\A\{\{$/, /^\}\}\z/] => ->(p, _, _) do
      p.type = :mathjax
      p.replace ["$$", XYMATRIX_START, p.to_s, XYMATRIX_END, "$$"].join("\n")
    end
  }.freeze
end
