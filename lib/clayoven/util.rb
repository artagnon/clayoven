module Util
  # Sorts a list of filenames lexicographically, but for 'index.clay', which is first
  def self.lex_sort(files) ["index"] + (files.reject { |f| f == "index.clay" }).sort end

  # Fetch all .clay files, ∞ directories deep
  def self.ls_files(config) Dir.glob("**/*.clay").reject { |entry| File.directory? entry } end
end
