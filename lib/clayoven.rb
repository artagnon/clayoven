require 'time'
require 'slim'
require 'sitemap_generator'
require_relative 'clayoven/config'
require_relative 'clayoven/clayfeed'
require_relative 'clayoven/claytext'
require_relative 'clayoven/httpd'

# Sorts a list of filenames lexicographically, but for 'index', which is first
def lex_sort files
  ['index'] + (files.reject { |f| f == 'index'}).sort
end

# Look one directory deep to fetch all files
def ls_files config
  Dir.glob('**/*')
    .reject { |entry| File.directory? entry }
    .reject { |entry| Regexp.union(/design\/.*/, /.clayoven\/.*/) =~ entry}
    .reject do |entry|
    config.ignore.any? { |pattern| %r{#{pattern}} =~ entry }
  end
end

module Clayoven
  class Git
    def initialize
      git_ns = `git diff --name-status @`
      if not git_ns.empty? then
        git_index = git_ns.split("\n").map { |line| line.split("\t")[0..1] }
        git_mod_index = git_index.select { |idx| idx.first == "M" }
        @modified = git_mod_index.map { |idx| idx.last }
        @added = (git_index - git_mod_index).map { |idx| idx.last }
      else
        @modified = []
        @added = []
      end
    end

    def modified? file
      @modified.include? file
    end

    def added? file
      @added.include? file
    end

    def added_or_modified? file
      added?(file) || modified?(file)
    end

    def auth_pub_dates file
      dates = `git log --follow --format="%aD" --date=unix #{file}`.split "\n"
      pubdate = if added_or_modified? file then
        Time.now else Time.parse dates.first
      end
      return pubdate, Time.parse(dates.last)
    end
  end

  class Page
    attr_accessor :filename, :permalink, :title, :topic, :body, :pubdate, :authdate, :paragraphs, :target, :topics, :indexfill

    # Intialize with filename and authored dates from git
    def initialize filename, gidx
      @filename = filename
      # If a file is in the git index, use Time.now; otherwise, log --follow it.
      @pubdate, @authdate = gidx.auth_pub_dates @filename
      @title, @body = (IO.read @filename).split "\n\n", 2
    end

    # Writes out HTML pages.  Takes a list of topics to render
    #
    # Prints a '[GEN]' line for every file it writes out.
    def render topics
      @topics = topics
      @paragraphs = if @body then ClayText.process @body else [] end
      Slim::Engine.set_options pretty: true, sort_attrs: false
      rendered = Slim::Template.new { IO.read 'design/template.slim' }.render self
      File.open(@target, _ = 'w') do |targetio|
        nbytes = targetio.write rendered
        puts "[GEN] #{@target} (#{nbytes} bytes out)"
      end
    end
  end

  class IndexPage < Page
    def initialize filename, gidx
      super
      if @filename == 'index'
        @permalink = @filename
      else
        @permalink, _ = filename.split '.index'
      end
      @topic = @permalink
      @target = "#{@permalink}.html"
    end
  end

  class ContentPage < Page
    def initialize filename, gidx
      super
      # There cannot be ContentPages nested under 'index'
      @topic, _ = @filename.split '/', 2
      @target = "#{@filename}.html"
      @permalink = @filename
    end
  end

  def self.page_objects index_files, content_files
    gidx = Git.new
    index_pages = index_files.map { |filename| IndexPage.new filename, gidx }
    content_pages = content_files.map { |filename| ContentPage.new filename, gidx }
    index_pages.each do |ip|
      ip.indexfill = content_pages
        .select { |cp| ip.topic == cp.topic }
        .sort_by { |cp| [-cp.authdate.to_i, cp.filename] }
    end
    return index_pages + content_pages
  end

  # Return index_pages and content_pages to generate
  def self.pages_to_regenerate index_files, content_files
    # Check the git index exactly once to determine dirty files
    gidx = Git.new

    # Find out the dirty content_pages
    dirty_content_pages = content_files
      .select { |filename| gidx.added_or_modified? filename }
      .map { |filename| ContentPage.new filename, gidx }

    # An index_file that is added (or deleted) should mark all index_files as dirty
    if index_files.any? { |filename| gidx.added? filename } then
      dirty_index_pages = index_files.map { |filename| IndexPage.new filename, gidx }
    else
      # First, see which index_pages are forced dirty by corresponding content_pages;
      # then, add to the list the ones that are dirty by themselves
      dirty_index_pages = dirty_content_pages.map do |dcp|
        IndexPage.new "#{dcp.topic}.index", gidx
      end
      dirty_index_pages += index_files
        .select { |filename| gidx.modified? filename }
        .map { |filename| IndexPage.new filename, gidx }
    end

    # Now, set the indexfill for index_pages by looking at all the content_files
    # corresponding to a dirty index_page.
    dirty_index_pages.each do |dip|
      dip.indexfill = content_files
        .select { |cf| cf.split('/', 2).first == dip.topic }
        .map { |cf| ContentPage.new cf, gidx }
        .sort_by { |cp| [-cp.authdate.to_i, cp.filename] }
    end
    return dirty_index_pages + dirty_content_pages
  end

  def self.generate_sitemap all_pages
    SitemapGenerator::Sitemap.default_host = 'https://artagnon.com'
    SitemapGenerator::Sitemap.public_path = '.'
    SitemapGenerator::Sitemap.create do
      all_pages.each do |page|
        add page.permalink, :lastmod => page.pubdate
      end
    end
  end

  def self.main is_aggressive = false
    abort 'error: index file not found; aborting' unless File.exists? 'index'

    # Collect the list of files from a directory listing
    all_files = ls_files Clayoven::ConfigData.new

    # We must have a 'design' directory.  I don't plan on making this
    # a configuration variable.
    unless Dir.entries('design').include? 'template.slim'
      abort 'error: design/template.slim file not found; aborting'
    end

    # index_files are files ending in '.index', 'index', and '404'
    # content_files are all other files (we've already applied ignore)
    # topics is the list of topics.  We need it for the sidebar
    index_files = ['index', '404'] + all_files.select { |file| /\.index$/ =~ file }
    content_files = all_files - index_files
    topics = lex_sort(index_files - ['404']).map { |file| file.split('.index').first }

    # Look for stray files.  All content_files are nested within directories
    content_files
      .reject { |file| topics.include? file.split('/', 2).first }
      .each do |stray|
      content_files = content_files - [stray]
      puts "[WARN] #{stray} is a stray file or directory; ignored"
    end

    if is_aggressive then
      # Ignore all dependency information and blindly generate everything;
      # required to generate sitemap
      all_pages = page_objects index_files, content_files
      all_pages.each { |page| page.render topics }
      generate_sitemap all_pages
    else
      # Get a list of pages to regenerate, and produce the final HTML using slim
      genpages = pages_to_regenerate index_files, content_files
      genpages.each { |page| page.render topics }
    end
  end
end
