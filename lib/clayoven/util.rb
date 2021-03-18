# Miscellanous utilities
module Clayoven::Util
  # Sorts a list of filenames lexicographically, but for 'index.clay'
  def self.lex_sort(files) (files.reject { |f| f == 'index.clay' }).sort end

  # Fetch all .clay files, arbitrary directories deep
  def self.ls_files() Dir.glob('**/*.clay').reject { |entry| File.directory? entry } end
end
