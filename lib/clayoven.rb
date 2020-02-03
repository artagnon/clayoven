require "slim"
require "colorize"
require "sitemap_generator"
require_relative "clayoven/config"
require_relative "clayoven/claytext"
require_relative "clayoven/httpd"
require_relative "clayoven/git"
require_relative "clayoven/util"

module Clayoven
  class Page
    attr_accessor :filename, :permalink, :title, :topic, :body, :lastmod, :crdate, :locations,
                  :paragraphs, :target, :topics, :indexfill

    # Intialize with filename and authored dates from git
    # Expensive due to log --follow; avoid creating Page objects when not necessary.
    def initialize(filename, git)
      @filename = filename
      # If a file is in the git index, use Time.now; otherwise, log --follow it.
      @lastmod, @crdate, @locations = git.metadata @filename
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
        puts "[#{"GEN".green}] #{@target} (#{nbytes.to_s.red} bytes out)"
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
    git = Git::Info.new @config.tzmap

    # An index_file that is added (or deleted) should mark all index_files as dirty
    if git.any_added?(index_files) || git.template_changed? || is_aggressive
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
        .sort_by { |cp| [-cp.crdate.to_i, cp.permalink] }
    end
    return dirty_index_pages + dirty_content_pages, git
  end

  def self.generate_sitemap(all_pages)
    SitemapGenerator::Sitemap.default_host = "https://#{@sitename}"
    SitemapGenerator::Sitemap.public_path = "."
    SitemapGenerator::Sitemap.create do
      all_pages.each do |page|
        add page.permalink, :lastmod => page.lastmod
      end
    end
  end

  def self.main(is_aggressive = false)
    # Only operate on git repositories
    toplevel = `git rev-parse --show-toplevel`.strip
    abort if toplevel.empty?
    Dir.chdir(toplevel) do
      # Write out template files, if necessary
      @config = Config::Data.new
      @sitename = @config.sitename

      # Collect the list of files from a directory listing
      all_files = Util::ls_files @config

      # index_files are files ending in '.index.clay' and 'index.clay'
      # content_files are all other files; topics is the list of topics: we need it for the sidebar
      index_files = ["index.clay"] + all_files.select { |file| /\.index\.clay$/ =~ file }
      content_files = all_files - index_files
      topic_pages = index_files.reject do |entry|
        @config.hidden.any? { |hidden_entry| hidden_entry == entry }
      end
      topics = Util::lex_sort(topic_pages).map { |file| file.split(".index.clay").first }

      # Look for stray files.  All content_files are nested within directories
      content_files
        .reject { |file| topics.include? file.split("/", 2).first }
        .each do |stray|
        content_files = content_files - [stray]
        puts "[WARN] #{stray} is a stray file or directory; ignored"
      end

      # Get a list of pages to regenerate, and produce the final HTML using slim
      genpages, git = pages_to_regenerate index_files, content_files, is_aggressive
      genpages.each { |page| page.render topics }

      # Finally, execute gulp and regenerate the sitemap conditionally
      is_aggressive = true if git.template_changed?
      puts `gulp --color` if git.design_changed? or is_aggressive
      generate_sitemap genpages if is_aggressive
    end
  end
end
