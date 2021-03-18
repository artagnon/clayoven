# Miscellanous utilities
module Clayoven::Util
  # Sorts a list of filenames lexicographically, but for 'index.clay'
  def self.lex_sort(files) (files.reject { |f| f == 'index.clay' }).sort end

  # Fetch all .clay files, arbitrary directories deep
  def self.ls_files; Dir.glob('**/*.clay').reject { |entry| File.directory? entry } end

  # Slice a paragraph along index and length, strip out the first line of the first paragraph,
  # the last line of the last paragraph, and finally return the join of the slices with two
  # newlines, the "fenced paragraph"
  def self.slice_strip_fences!(paragraphs, index, length)
    slices = paragraphs[index, length]
    slices[0] = slices[0].split("\n")[1..].join("\n")
    slices[-1] = slices[-1].split("\n")[..-2].join("\n")
    slices.join("\n\n")
  end

  # Minify css and js files, by forking out to npm
  def self.minify_design
    puts "[#{'NPM'.green} ]: Minifying js and css"
    fork { exec 'npm run --silent minify' }
    Process.waitall
  end

  # Fork out to npm to render math
  def self.render_math(htmlfiles)
    fork { exec "npm run --silent jax -- #{htmlfiles}" }
    Process.waitall
  end
end
