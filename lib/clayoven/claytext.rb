# -*- coding: utf-8 -*-
module ClayText
  # These are the values that Paragraph.type can take
  PARAGRAPH_TYPES = %i[plain ulitems olitems subheading header footer codeblock]

  # see: http://php.net/manual/en/function.htmlspecialchars.php
  HTMLESCAPE_RULES = {
    '&' => '&amp;',
    '"' => '&quot;',
    "'" => '&#39;',
    '<' => '&lt;',
    '>' => '&gt;',
    '...' => '&hellip;'
  }

  ROMAN_NUMERALS = {
    10 =>'x',
    9 => 'ix',
    5 => 'v',
    4 => 'iv',
    1 => 'i'
  }

  def self.to_arabic str
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
      lines.map! { |k| k.gsub(regex, '') }
      paragraph.type = :olitems
      paragraph.start = match if match
    end,

    # The Roman-numeral version of ol
    /^\(([ivx]+)\) / => lambda do |paragraph, lines, regex|
      match = lines.first.match(regex)[1]
      lines.map! { |k| k.gsub(regex, '') }
      paragraph.type = :olitems
      paragraph.prop = :i
      paragraph.start = to_arabic(match) if match
    end,

    # The alphabetic version of ol
    /^\(([a-z])\) / => lambda do |paragraph, lines, regex|
      match = lines.first.match(regex)[1]
      lines.map! { |k| k.gsub(regex, '') }
      paragraph.type = :olitems
      paragraph.prop = :a
      paragraph.start = match - 'a' + 1 if match
    end,

    # If all the lines in a paragraph begin with "- ", those
    # characters are stripped from the content, and the paragraph is
    # marked as an :ulitems.
    /^- / => lambda do |paragraph, lines, regex|
      lines.map! { |k| k.gsub(regex, '') }
      paragraph.type = :ulitems
    end,

    # If the paragraph has exactly one line prefixed with a '# ',
    # it is put into the :subheading type.
    /^# / => lambda do |paragraph, lines, regex|
      lines.map! { |k| k.gsub(regex, '') }
      paragraph.type = :subheading
    end,

    # If all the lines in a paragraph begin with '[\d+]: ', the
    # paragraph is marked as :footer.  Also, a regex substitution runs
    # on each line turning every link like http://url-over-33-chars to
    # <a href="http://google.com">30-characters-of-the-li...</a>
    # Also, special case github.com links.
    /^\[\d+\]: / => lambda do |paragraph, lines, regex|
      paragraph.type = :footer
      lines.map! { |k| k.gsub(%r{^(\[\d+\]:) (.*://(.*))}) do
          if $3.start_with? 'github.com'
            text = 'gh:' + $3[11, 30]
            trunc_len = 44 # 33 + 11
          else
            text = $3[0, 30]
            trunc_len = 33 # 33 = 30 + "...".size
          end
          "#{$1} <a href=\"#{$2}\">#{text}#{%{...} if $3.length > trunc_len}</a>"
        end
      }
    end
  }

  # A paragraph of text
  #
  # :content contains its content
  # :type can be one of PARAGRAPH_TYPES
  # :level is an integer which has a type-specific meaning
  class Paragraph
    attr_accessor :contents, :type, :prop, :start

    def initialize contents
      @contents = contents
      @type = :plain
      @prop = :none
      @start = :none

      # Generate is_*? methods for PARAGRAPH_TYPES
      Paragraph.class_eval do
        ClayText::PARAGRAPH_TYPES.each do |type|
          define_method("is_#{type.to_s}?") { @type == type }
        end
      end
    end
  end

  # Takes a body of claytext, breaks it up into paragraphs, and
  # applies various rules on it.
  #
  # Returns a list of Paragraphs
  def self.process body
    # Split the body into Paragraphs
    paragraphs = []
    body.split("\n\n").each do |content|
      paragraphs << Paragraph.new(content.lines.map! { |l| l.strip })
    end

    # Special matching for the first paragraph.  This paragraph will
    # be marked header:
    #
    # (This is a really long first paragraph blah-blah-blah-blah-blah
    # that spans to two lines)
    if paragraphs[0].contents.size == 1 and
       paragraphs[0].contents[0].start_with? '(' and
       paragraphs[0].contents[0].end_with? ')'
      paragraphs[0].type = :header
    end

    paragraphs.each do |paragraph|
      if (paragraph.contents.size > 0 and paragraph.contents[0].start_with? '[[' and paragraph.contents[-1].end_with? ']]') then
        paragraph.contents = paragraph.contents[1..-2]
        paragraph.type = :codeblock
      else
        unless (paragraph.contents.size > 0 and paragraph.contents[0].start_with? '\[' and paragraph.contents[-1].end_with? '\]')
          # First, htmlescape the body text
          paragraph.contents.each { |l| l.gsub!(/[&"'<>]/, ClayText::HTMLESCAPE_RULES) }
        end
      end
    end

    paragraphs.each do |paragraph|
      # Apply the PARAGRAPH_LINE_FILTERS on all the paragraphs
      ClayText::PARAGRAPH_LINE_FILTERS.each do |regex, lambda_cb|
        if paragraph.contents.first and paragraph.contents.all? regex
          lambda_cb.call paragraph, paragraph.contents, regex
        end
      end
    end

    paragraphs
  end
end
