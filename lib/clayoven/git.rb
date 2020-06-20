# -*- coding: utf-8 -*-

module Git
  class Info
    def initialize(tzmap)
      git_ns = `git diff --name-status @ 2>/dev/null`
      @tzmap = tzmap
      @untracked = `git ls-files --others --exclude-standard`.split "\n"
      if not git_ns.empty?
        git_index = git_ns.split("\n").map { |line| line.split("\t")[0..1] }
        git_mod_index = git_index.select { |idx| idx.first == "M" }
        @modified = git_mod_index.map &:last
        @added = (git_index - git_mod_index).map &:last
      else
        @modified = []
        @added = []
      end
    end

    def modified?(file) @modified.any?(file) end
    def added?(file) @added.any?(file) || @untracked.any?(file) end
    def any_added?(files) files.any? { |file| added? file } end
    def added_or_modified?(file) added?(file) || modified?(file) end
    def template_changed?; modified? "design/template.slim" end
    def design_changed?; modified? %r{design/.+\.(css|js)} end

    # Returns a #<Last updated date>|#<Creation date>|[#<Location string>]
    def metadata(file)
      dates = `git log --follow --format="%aD" --date=unix #{file} 2>/dev/null`.split("\n")
                                                                               .map { |d| Time.parse d }
      locs = dates.map { |d| d.strftime("%z") }.map { |tz| @tzmap[tz] }.uniq
      return Time.now, Time.now, locs if not dates.first
      lastmod = added_or_modified?(file) ? Time.now : dates.first
      return lastmod, dates.last, locs
    end
  end
end
