# Git metadata information for the clayoven repository
#
# Information from the git index via new is cheap, but metadata is expensive due to the
# `git log --follow` invocation.
class Clayoven::Git
  # Look at the git index immediately; accepts a Clayoven::Config#tzmap hashtable
  def initialize(tzmap)
    git_ns = `git diff --name-status @ 2>/dev/null`
    @tzmap = tzmap
    @untracked = `git ls-files --others --exclude-standard`.split "\n"
    if !git_ns.empty?
      git_index = git_ns.split("\n").map { |line| line.split("\t")[0..1] }
      git_mod_index = git_index.select { |idx| idx.first == "M" }
      @modified = git_mod_index.map(&:last)
      @added = (git_index - git_mod_index).map(&:last)
    else
      @modified = []
      @added = []
    end
  end

  # Return the toplevel directory in the git tree, or an empty string.
  def self.toplevel
    `git rev-parse --show-toplevel 2>/dev/null`.strip
  end

  # Checks if a file was modified, from the git index.
  def modified?(file)
    @modified.any?(file) || @untracked.any?(file)
  end

  # Checks if a file was added, from the git index.
  def added?(file)
    @added.any?(file) || @untracked.any?(file)
  end

  # Checks if a file was adddd or modified, from git index.
  def added_or_modified?(file)
    added?(file) || modified?(file)
  end

  # Checks if any of the files in the list of files were added, from git index.
  def any_added?(files)
    files.any? { |file| added? file }
  end

  # Indicates if the site was changed in a way that requires a full rebuild.
  def requires_aggressive?
    (
      ["design/template.slim"] + Clayoven::Util.ls_files(".clayoven/*") +
        Clayoven::Util.ls_files("lib/*")
    ).any? { |file| modified? file }
  end

  # Checks if the stylesheets or js files were changed.
  def design_changed?
    (
      Clayoven::Util.ls_files("design/*.sass") +
        Clayoven::Util.ls_files("design/*.js")
    ).any? { |file| modified? file }
  end

  # Returns a `[#{Last modified timestamp} # {Creation timestamp} #{Location strings}]`
  # The timestamps default to `Time.now` if the file hasn't been committed.
  # Expensive compared to HTML generation by Claytext.
  def metadata(file)
    dates =
      `git log --follow --format="%aD" --date=unix #{file} 2>/dev/null`.split(
        "\n"
      )
        .map { |d| Time.parse d }
    locs =
      dates.map { |d| d.strftime("%z") }.map { |tz| @tzmap[tz] }.flatten.uniq
    return Time.now, Time.now, locs unless dates.first

    lastmod = added_or_modified?(file) ? Time.now : dates.first
    [lastmod, dates.last, locs]
  end
end
