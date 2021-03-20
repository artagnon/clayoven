# Git metadata information for the clayoven repository
class Clayoven::Git
  # Look at the git index immediately; accepts a `Config#tzmap` hashtable
  def initialize(tzmap)
    git_ns = `git diff --name-status @ 2>/dev/null`
    @tzmap = tzmap
    @untracked = `git ls-files --others --exclude-standard`.split "\n"
    if !git_ns.empty?
      git_index = git_ns.split("\n").map { |line| line.split("\t")[0..1] }
      git_mod_index = git_index.select { |idx| idx.first == 'M' }
      @modified = git_mod_index.map(&:last)
      @added = (git_index - git_mod_index).map(&:last)
    else
      @modified = []
      @added = []
    end
  end

  # Indicates if a file was modified, from git index
  def modified?(file) @modified.any?(file) end

  # Indicates if a file was added, from git index
  def added?(file) @added.any?(file) || @untracked.any?(file) end

  # Indicates if any of the files in the list of files were added
  def any_added?(files) files.any? { |file| added? file } end

  # Indicates if any of the files in the list of files were added or modified
  def added_or_modified?(file) added?(file) || modified?(file) end

  # Indicates if the config or the template was changed
  def template_changed?
    modified?('design/template.slim') || modified?('.clayoven/hidden') || modified?('.clayoven/tz') ||
      modified?('.clayoven/st') || modified?('.clayoven/sitename')
  end

  # Indicates if 'design/style.css' or 'design/script.js' was changed
  def design_changed?; modified?('design/style.css') || modified?('design/script.js') end

  # Returns a [#{Last modified date} # {Creation date} #{Location strings}]
  def metadata(file)
    dates = `git log --follow --format="%aD" --date=unix #{file} 2>/dev/null`.split("\n")
                                                                             .map { |d| Time.parse d }
    locs = dates.map { |d| d.strftime('%z') }.map { |tz| @tzmap[tz] }.uniq
    return Time.now, Time.now, locs unless dates.first

    # Give the user 60 seconds to test and commit
    lastmod = added_or_modified?(file) ? Time.now + 60 : dates.first
    [lastmod, dates.last, locs]
  end
end
