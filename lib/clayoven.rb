require "time"
require "slim"
require "sitemap_generator"
require_relative "clayoven/config"
require_relative "clayoven/clayfeed"
require_relative "clayoven/claytext"
require_relative "clayoven/httpd"

# Sorts a list of filenames lexicographically, but for 'index.clay', which is first
def lex_sort(files) ["index"] + (files.reject { |f| f == "index.clay" }).sort end

# Look one directory deep to fetch all .clay files
def ls_files(config) Dir.glob("**/*.clay").reject { |entry| File.directory? entry } end

module Clayoven
  class Git
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

    def auth_pub_dates(file)
      dates = `git log --follow --format="%aD" --date=unix #{file}`.split "\n"
      return Time.now, Time.now if not dates.first
      pubdate = if added_or_modified? file
                  Time.now
                else Time.parse dates.first                 end
      return pubdate, Time.parse(dates.last)
    end
  end

  class Page
    attr_accessor :filename, :permalink, :title, :topic, :body, :pubdate, :authdate, :paragraphs,
                  :target, :topics, :indexfill

    # Intialize with filename and authored dates from git
    # Expensive due to log --follow; avoid creating Page objects when not necessary.
    def initialize(filename, git)
      @filename = filename
      # If a file is in the git index, use Time.now; otherwise, log --follow it.
      @pubdate, @authdate = git.auth_pub_dates @filename
      @title, @body = (IO.read @filename).split "\n\n", 2
    end

    # Writes out HTML pages.  Takes a list of topics to render
    #
    # Prints a '[GEN]' line for every file it writes out.
    def render(topics)
      @topics = topics
      @paragraphs = if @body and not @body.empty? then ClayText.process @body else [] end
      Slim::Engine.set_options pretty: true, sort_attrs: false
      rendered = Slim::Template.new { IO.read "design/template.slim" }.render self
      File.open(@target, _ = "w") do |targetio|
        nbytes = targetio.write rendered
        puts "[GEN] #{@target} (#{nbytes} bytes out)"
      end
    end
  end

  class IndexPage < Page
    def initialize(filename, git)
      super
      # Special handling for 'index.clay': every other IndexFile is a '*.index.clay'
      @permalink = if @filename == "index.clay"
                     filename.split(".clay").first
                   else filename.split(".index.clay").first                    end
      @topic = @permalink
      @target = "#{@permalink}.html"
    end
  end

  class ContentPage < Page
    def initialize(filename, git)
      super
      # There cannot be ContentPages nested under 'index'
      @topic, _ = @filename.split "/", 2
      @permalink = @filename.split(".clay").first
      @target = "#{@permalink}.html"
    end
  end

  # Return index_pages and content_pages to generate; we work with
  # content_files and index_files, because converting them to Page
  # objects prematurely will result in unnecessary log --follows
  def self.pages_to_regenerate(index_files, content_files, is_aggressive)
    # Check the git index exactly once to determine dirty files
    git = Git.new

    # An index_file that is added (or deleted) should mark all index_files as dirty
    if git.any_added?(index_files) || git.design_changed? || is_aggressive
      dirty_index_pages = index_files.map { |filename| IndexPage.new filename, git }
      dirty_content_pages = content_files.map { |filename| ContentPage.new filename, git }
    else
      # Find out the dirty content_pages
      dirty_content_pages = content_files
        .select { |filename| git.added_or_modified? filename }
        .map { |filename| ContentPage.new filename, git }

      # First, see which index_pages are forced dirty by corresponding content_pages;
      # then, add to the list the ones that are dirty by themselves; avoid adding the
      # index page twice when there are two dirty content_pages under the same index
      dirty_index_pages = dirty_content_pages.map { |dcp| "#{dcp.topic}.index.clay" }.uniq
                                             .map { |dif| IndexPage.new dif, git }
      dirty_index_pages += index_files
        .select { |filename| git.modified? filename }
        .map { |filename| IndexPage.new filename, git }
    end

    # Now, set the indexfill for index_pages by looking at all the content_files
    # corresponding to a dirty index_page.
    dirty_index_pages.each do |dip|
      dip.indexfill = content_files
        .select { |cf| cf.split("/", 2).first == dip.topic }
        .map { |cf| ContentPage.new cf, git }
        .sort_by { |cp| [-cp.authdate.to_i, cp.permalink] }
    end
    return dirty_index_pages + dirty_content_pages
  end

  def self.generate_sitemap(all_pages, is_aggressive)
    return if not is_aggressive
    SitemapGenerator::Sitemap.default_host = "https://artagnon.com"
    SitemapGenerator::Sitemap.public_path = "."
    SitemapGenerator::Sitemap.create do
      all_pages.each do |page|
        add page.permalink, :lastmod => page.pubdate
      end
    end
  end

  def self.main(is_aggressive = false)
    abort "error: index.clay file not found; aborting" unless File.exists? "index.clay"

    # Collect the list of files from a directory listing
    config = Clayoven::ConfigData.new
    all_files = ls_files config

    # We must have a 'design' directory.
    unless Dir.entries("design").include? "template.slim"
      abort "error: design/template.slim file not found; aborting"
    end

    # index_files are files ending in '.index.clay' and 'index.clay'
    # content_files are all other files; topics is the list of topics: we need it for the sidebar
    index_files = ["index.clay"] + all_files.select { |file| /\.index\.clay$/ =~ file }
    content_files = all_files - index_files
    topic_pages = index_files.reject do |entry|
      config.hidden.any? { |pattern| %r{#{pattern}} =~ entry }
    end
    topics = lex_sort(topic_pages).map { |file| file.split(".index.clay").first }

    # Look for stray files.  All content_files are nested within directories
    content_files
      .reject { |file| topics.include? file.split("/", 2).first }
      .each do |stray|
      content_files = content_files - [stray]
      puts "[WARN] #{stray} is a stray file or directory; ignored"
    end

    # Get a list of pages to regenerate, and produce the final HTML using slim
    genpages = pages_to_regenerate index_files, content_files, is_aggressive
    genpages.each { |page| page.render topics }
    generate_sitemap genpages, is_aggressive
  end
end
