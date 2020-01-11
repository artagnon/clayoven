require "time"

module Git
  class Info
    def initialize
      git_ns = `git diff --name-status @`
      @untracked = `git ls-files --others --exclude-standard`.split "\n"
      if not git_ns.empty?
        git_index = git_ns.split("\n").map { |line| line.split("\t")[0..1] }
        git_mod_index = git_index.select { |idx| idx.first == "M" }
        @modified = git_mod_index.map { |idx| idx.last }
        @added = (git_index - git_mod_index).map { |idx| idx.last }
      else
        @modified = []
        @added = []
      end
    end

    def modified?(file) @modified.include? file end
    def added?(file) @added.include?(file) || @untracked.include?(file) end
    def any_added?(files) files.any? { |file| added? file } end
    def added_or_modified?(file) added?(file) || modified?(file) end
    def design_changed?; modified? "design/template.slim" end

    def metadata(file)
      dates = `git log --follow --format="%aD" --date=unix #{file}`.split "\n"
      return Time.now, Time.now if not dates.first
      pubdate = if added_or_modified? file
                  Time.now
                else Time.parse dates.first                 end
      return pubdate, Time.parse(dates.last), ["Paris"]
    end
  end
end
