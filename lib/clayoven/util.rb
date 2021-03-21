# Miscellanous utilities
module Clayoven::Toplevel::Util
  # Sorts a list of filenames lexicographically, but for 'index.clay'
  def self.lex_sort(files) (files.reject { |f| f == 'index.clay' }).sort end

  # Fetch all .clay files, ∞ directories deep
  def self.ls_files; Dir.glob('**/*.clay').reject { |entry| File.directory? entry } end

  # Execute a process so that its output is displayed synchronously, but wait until it finishes
  def self.fork_exec(command)
    fork { exec command }
    Process.waitall
  end

  # Minify css and js files, by forking out to npm
  def self.minify_design
    puts "[#{'NPM'.green} ]: Minifying js and css"
    fork_exec 'npm run --silent minify'
  end

  # Fork out to npm to render math, via MathJaX and XyJaX; very expensive if you have a lot of math on your site.
  def self.render_math(htmlfiles)
    fork_exec "npm run --silent jax -- #{htmlfiles}"
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
