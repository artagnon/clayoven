# The claytext paragraph processor
module Clayoven::Claytext
  require_relative 'transforms'

  # A paragraph of text; just a String with additional accessors
  class Paragraph < String
    # `:type` is a `Symbol` like `:plain` or `:mathjax`
    attr_accessor :type

    # `:prop` is auxiliary type-specific information; could be any type
    attr_accessor :prop

    # `:olstart` is an auxiliary field for list-numbering
    attr_accessor :olstart

    # `:bookmark` is another auxiliary field that makes sense in :subheading
    attr_accessor :bookmark

    # Initializes the superclass, and sets @type to :plain
    def initialize(contents)
      super
      @type = :plain
      @prop = :none
    end
  end

  # Merge `Paragraph` entries with fences marked by the start regex `fregex` and end regex `lregex`
  def self.merge_fenced!(paragraphs, fregex, lregex)
    mb = Struct.new(:block, :fc, :lc)
    matched_blocks = []
    paragraphs.each_with_index do |p, pidx|
      pmatch = fregex.match p
      next unless pmatch

      paragraphs[pidx..].each_with_index do |q, idx|
        qmatch = lregex.match q
        next unless qmatch

        # Replace paragraph p with all the paragraphs from pidx to pidx + idx, after stripping out the delims.
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

  # Perform the transforms in `Transforms::FENCED` on `Paragraph` entries in-place
  def self.fenced_transforms!(paragraphs)
    # For MathJax, exercises, codeblocks, and other fenced content
    Transforms::FENCED.each do |delims, lambda_cb|
      blocks = merge_fenced! paragraphs, delims[0], delims[1]
      blocks.each { |blk| lambda_cb.call blk.block, blk.fc, blk.lc }
    end
  end

  # Perform the transforms in `Transforms::LINE` on `Paragraph` entries in-place
  def self.line_transforms!(paragraphs)
    paragraphs.filter { |p| p.type == :plain }.each do |p|
      # Apply the Transforms::LINE on all the paragraphs
      Transforms::LINE.each do |regex, lambda_cb|
        lambda_cb.call(p, regex) if p.split("\n").all?(regex)
      end
    end
  end

  # We only HTML escape very few things, for simplicity
  HTMLESCAPE_RULES = {
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;'
  }.freeze

  # Insert <{mark, a}> in certain paragraph kinds
  def self.process_inline_markdown(paragraphs)
    paragraphs.select { |p| %i[plain olitems exercise footer blurb].count(p.type).positive? }.each do |p|
      p.gsub!(/`([^`]+)`/, '<mark>\1</mark>')
      p.gsub!(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
    end
    paragraphs
  end

  ##
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

    # at the end of both sets of transforms, htmlescape everything but mathjax
    paragraphs.reject { |p| p.type == :mathjax }.each do |p|
      p.gsub!(/[<>&]/, HTMLESCAPE_RULES)
    end

    # Insert HTML breaks in :plain paragraphs
    paragraphs.filter { |p| p.type == :plain }.each { |p| p.gsub!(/\n/, "<br/>\n") }

    # Process `...` and `[...](...)`
    process_inline_markdown paragraphs
  end
end
