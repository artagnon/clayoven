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
    def render(topics, template)
      @topics = topics
      @paragraphs = if @body and not @body.empty? then ClayText.process @body else [] end
      Slim::Engine.set_options pretty: true, sort_attrs: false
      rendered = Slim::Template.new { template }.render self
      File.open(@target, _ = "w") do |targetio|
        nbytes = targetio.write rendered
        puts "[#{"GEN".green}] #{@target} (#{nbytes.to_s.red} bytes out)"
      end
    end
  end

  class IndexPage < Page
    attr_accessor :subtopics

    def initialize(filename, git)
      super
      # Special handling for 'index.clay': every other IndexFile is a '*.index.clay'
      @permalink = if @filename == "index.clay"
          "index"
        else filename.split(".index.clay").first         end
      @target = "#{@permalink}.html"
    end

    def fillindex(cps)
      st = Struct.new(:title, :cps, :begints, :endts)
      cps = cps.sort_by { |cp| -cp.crdate.to_i }
      @subtopics = cps.group_by { |cp| cp.subtopic }.map { |subtop, cps| st.new(subtop, cps, cps.last.crdate, cps.first.lastmod) }
    end
  end

  class ContentPage < IndexPage
    attr_accessor :subtopic

    def initialize(filename, git)
      super
      # There cannot be ContentPages nested under 'index'
      @topic, @subtopic, _ = @filename.split "/", 3
      @subtopic = nil if @subtopic.end_with?(".clay")
      @permalink = @filename.split(".clay").first
      @target = "#{@permalink}.html"
    end
  end

  def self.dirty_pages(index_files, content_files, is_aggressive)
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

    return dirty_index_pages, dirty_content_pages, git
  end

  # Return index_pages and content_pages to generate; we work with
  # content_files and index_files, because converting them to Page
  # objects prematurely will result in unnecessary log --follows
  def self.pages_to_regenerate(index_files, content_files, is_aggressive)
    dirty_index_pages, dirty_content_pages, git = dirty_pages index_files, content_files, is_aggressive

    # Now, set the indexfill for index_pages by looking at all the content_files
    # corresponding to a dirty index_page.
    # Additionally, reject hidden content_files from the corresponding indexfill
    dirty_index_pages.each do |dip|
      cps = content_files.reject do |cf|
        @config.hidden.any? { |hidden_entry| "#{hidden_entry}.clay" == cf }
      end
        .select { |cf| cf.split("/", 2).first == dip.permalink }
        .map { |cf| ContentPage.new cf, git }
      dip.fillindex cps
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

  def self.index_content_files(all_files)
    # index_files are files ending in '.index.clay' and 'index.clay'
    # content_files are all other files; topics is the list of topics: we need it for the sidebar
    index_files = ["index.clay"] + all_files.select { |file| /\.index\.clay$/ =~ file }
    content_files = all_files - index_files
    all_topics = Util::lex_sort(index_files).map { |file| file.split(".index.clay").first }
    topics = all_topics.reject do |entry|
      @config.hidden.any? { |hidden_entry| hidden_entry == entry }
    end

    # Look for stray files.  All content_files are nested within directories
    content_files
      .reject { |file| all_topics.include? file.split("/").first }
      .each do |stray|
      content_files = content_files - [stray]
      puts "[#{"WARN".red}] #{stray} is a stray file or directory; ignored"
    end

    return index_files, content_files, topics
  end

  def self.main(is_aggressive = false)
    # Only operate on git repositories
    toplevel = `git rev-parse --show-toplevel`.strip
    abort "[#{"ERR".red}] Not a clayoven project" if toplevel.empty? or not File.directory? ".clayoven"
    Dir.chdir(toplevel) do
      # Write out template files, if necessary
      @config = Config::Data.new
      @sitename = @config.sitename

      # Collect the list of files from a directory listing
      all_files = Util::ls_files @config

      # From all_files, get the list of index_files, content_files, and topics
      index_files, content_files, topics = index_content_files all_files

      # Get a list of pages to regenerate, and produce the final HTML using slim
      genpages, git = pages_to_regenerate index_files, content_files, is_aggressive
      genpages.each { |page| page.render topics, @config.template }

      # Finally, execute gulp and regenerate the sitemap conditionally
      is_aggressive = true if git.template_changed?
      puts `gulp --color` if git.design_changed? or is_aggressive
      generate_sitemap genpages if is_aggressive
    end
  end
end
