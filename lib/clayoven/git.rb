# \Git \metadata information for the clayoven repository
#
# Information from the git index via new is cheap, but metadata is expensive due to the `git log --follow`
# invocation.
class Clayoven::Git
  # Look at the git index immediately; accepts a Clayoven::Config#tzmap hashtable
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

  # Return the toplevel directory in the git tree, or an empty string
  def self.toplevel; `git rev-parse --show-toplevel 2>/dev/null`.strip end

  # Indicates if a file was modified, from git index
  def modified?(file) @modified.any?(file) || @untracked.any?(file) end

  # Indicates if a file was added, from git index
  def added?(file) @added.any?(file) || @untracked.any?(file) end

  # Indicates if any of the files in the list of files were added, from git index
  def any_added?(files) files.any? { |file| added? file } end

  # Indicates if any of the files in the list of files were added or modified, from git index
  def added_or_modified?(file) added?(file) || modified?(file) end

  # Indicates if the config or the template was changed, in a way that requires a full rebuild
  def template_changed?
    modified?('design/template.slim') || modified?('.clayoven/hidden') ||
      modified?('.clayoven/tz') || modified?('.clayoven/subtopics')
  end

  # Indicates if `design/style.sass` or `design/script.js` was changed
  def design_changed?; modified?('design/style.sass') || modified?('design/script.js') end

  # Returns a `[#{Last modified timestamp} # {Creation timestamp} #{Location strings}]`
  # The timestamps default to `Time.now` if the file hasn't been committed.
  # Expensive compared to HTML generation by Claytext.
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
