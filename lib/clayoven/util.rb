module Util
  # Sorts a list of filenames lexicographically, but for 'index.clay', which is first
  def self.lex_sort(files) ["index"] + (files.reject { |f| f == "index.clay" }).sort end

  # Look one directory deep to fetch all .clay files
  def self.ls_files(config) Dir.glob("**/*.clay").reject { |entry| File.directory? entry } end
end
