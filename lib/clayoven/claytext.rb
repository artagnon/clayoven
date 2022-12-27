# The claytext paragraph processor
#
# The actual transformation rules are the constants in Clayoven::Claytext::Transforms.
module Clayoven::Claytext
  require_relative "transforms"

  # A paragraph of text; just a `String` with additional accessors
  class Paragraph < String
    # `Symbol` like `:plain` or `:mathjax`
    attr_accessor :type

    # An auxiliary type-specific information; could be any \type
    attr_accessor :prop

    # An auxiliary field for list-numbering; makes sense when type is `:olitems`
    attr_accessor :olstart

    # Another auxiliary field that makes sense in when type is `:subheading`
    attr_accessor :bookmark

    # Initializes the superclass, and sets type to `:plain`
    def initialize(contents)
      super
      @type = :plain
      @prop = :none
    end
  end

  # Merge Paragraph entries with fences marked by the start regex fregex and end regex lregex
  def self.merge_fenced!(paragraphs, fregex, lregex)
    mb = Struct.new(:block, :fc, :lc)
    matched_blocks = []
    paragraphs.each_with_index do |p, pidx|
      pmatch = fregex.match p
      next unless pmatch

      paragraphs[pidx..].each_with_index do |q, idx|
        qmatch = lregex.match q
        next unless qmatch

        # Replace paragraph p with all the paragraphs from pidx to pidx + idx,
        # after stripping out the delims.
        # The final result, the "fenced paragraph" sits at pidx.
        p.replace(Util.slice_strip_fences!(paragraphs, pidx, idx + 1))
        matched_blocks << mb.new(p, pmatch, qmatch)

        # The final result is at pidx; throw out all the idx paragraphs, starting at pidx + 1
        paragraphs.slice! pidx + 1, idx
        break
      end
    end
    matched_blocks
  end

  # Perform the transforms in Clayoven::Claytext::Transforms::FENCED on Paragraph entries in-place
  def self.fenced_transforms!(paragraphs)
    # For MathJax, exercises, codeblocks, and other fenced content
    Transforms::FENCED.each do |delims, lambda_cb|
      blocks = merge_fenced! paragraphs, delims[0], delims[1]
      blocks.each { |blk| lambda_cb.call blk.block, blk.fc, blk.lc }
    end
  end

  # Perform the transforms in Clayoven::Claytext::Transforms::LINE on Paragraph entries in-place
  def self.line_transforms!(paragraphs)
    # Preprocess lines ending with ' \\' and insert a special unicode char for conversion to <br>
    paragraphs.each { |p| p.gsub! " \\\\\n", "\u{23CE}" }

    # Now do the all the line transforms, never operating on a line more than once
    Transforms::LINE.each do |regex, lambda_cb|
      paragraphs
        .filter { |p| p.type == :plain and p.split("\n").all? regex }
        .each do |p|
          # Strip the regex before calling the lambda
          match = p.match regex
          p.gsub! regex, ""
          lambda_cb.call p, match
        end
    end
  end

  # We only HTML escape very few things, for simplicity
  HTMLESCAPE_RULES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;" }.freeze

  # Insert <{mark, strong, em, a, br}> into the paragraph after escaping HTML
  def self.inline_transforms!(paragraphs)
    paragraphs.each do |p|
      p.replace p
                  .gsub(/[<>&]/, HTMLESCAPE_RULES)
                  .gsub(/`([^`]+)`/, '<mark>\1</mark>')
                  .gsub(/!\{([^\}]+)\}/, '<strong>\1</strong>')
                  .gsub(/!_\{([^\}]+)\}/, '<em>\1</em>')
                  .gsub(/\[([^\[\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
                  .gsub("\u{23CE}", "<br>")
    end
  end

  # Takes a body of claytext (`String`), breaks it up into paragraphs, and
  # applies various rules on it.
  #
  # Returns an `Array` of Paragraph
  def self.process(body)
    # Split the body into Paragraphs
    paragraphs = body.split("\n\n").map { |p| Paragraph.new p.rstrip }

    # First, do the fenced transforms on all paragraphs
    fenced_transforms! paragraphs

    # Then, do the line transforms on paragraphs untouched by the fenced transforms
    line_transforms! (paragraphs.filter { |p| p.type == :plain })

    # Finally, do inline transforms on paragraphs untouched by the fenced transforms
    inline_transforms! (
                         paragraphs.reject { |p|
                           %i[codeblock images mathjax].count(p.type).positive?
                         }
                       )

    # Result: paragraphs
    paragraphs
  end
end
