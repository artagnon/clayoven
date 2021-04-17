# Miscellanous utilities
module Clayoven::Toplevel::Util
  # Sorts a list of filenames lexicographically, but for 'index.clay'
  def self.lex_sort(files) (files.reject { |f| f == 'index.clay' }).sort end

  # Fetch all .clay files, ∞ directories deep
  def self.ls_files; Dir.glob('**/*.clay').reject { |entry| File.directory? entry } end

  # Minify css and js files, by shelling out to npm
  def self.minify_design
    puts "[#{'YARN'.green}]: Minifying js and css"
    system 'yarn minify'
  end

  # Shell out to npm to render math, via MathJaX and XyJaX; very expensive if you have a lot of math on your site.
  def self.render_math(htmlfiles)
    system "yarn jax -- #{htmlfiles}"
  end
end

# Miscellanous utilities
module Clayoven::Claytext::Util
  # Slice a paragraph along index and length, strip out the first line of the first paragraph,
  # the last line of the last paragraph, and finally return the join of the slices with two
  # newlines, the "fenced paragraph"
  def self.slice_strip_fences!(paragraphs, index, length)
    slices = paragraphs[index, length]
    slices[0] = slices[0].split("\n")[1..].join("\n")
    slices[-1] = slices[-1].split("\n")[..-2].join("\n")
    slices.join("\n\n")
  end
end

# Miscellanous utilities
module Clayoven::Claytext::Transforms::Util
  # For roman-numeralized lists like (i), (ii)
  ROMAN_NUMERALS = {
    10 => 'x',
    9 => 'ix',
    5 => 'v',
    4 => 'iv',
    1 => 'i'
  }.freeze

  # Do a roman to arabic conversion
  def self.to_arabic(str)
    result = 0
    ROMAN_NUMERALS.each_value do |roman|
      while str.start_with?(roman)
        result += ROMAN_NUMERALS.invert[roman]
        str = str.slice(roman.length, str.length)
      end
    end
    result
  end
end
