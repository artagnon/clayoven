require 'slim'
require 'colorize'
require 'progressbar'
require 'sitemap_generator'

# The toplevel module for clayoven
module Clayoven
  # Require the various submodules
  require_relative 'clayoven/config'
  require_relative 'clayoven/claytext'
  require_relative 'clayoven/httpd'
  require_relative 'clayoven/git'
  require_relative 'clayoven/util'

  # A general page: IndexPage and ContentPage inherit from Page
  class Page
    attr_accessor :permalink, :title, :topic, :lastmod, :crdate, :locations,
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
    def render(topics, template)
      @topics = topics
      @paragraphs = @body.empty? ? [] : (ClayText.process @body)
      Slim::Engine.set_options pretty: true, sort_attrs: false
      rendered = Slim::Template.new { template }.render self
      File.open(@target, _ = 'w') do |targetio|
        targetio.write rendered
      end
    end
  end

  # For .index.clay files
  class IndexPage < Page
    attr_accessor :subtopics

    def initialize(filename, git)
      super

      # Special handling for 'index.clay': every other IndexFile is a '*.index.clay'
      @permalink = if @filename == 'index.clay'
                     'index'
                   else
                     filename.split('.index.clay').first
                   end
      @target = "#{@permalink}.html"
    end

    def update_crdate_lastmod(content_pages)
      # crdate and lastmod are decided, not based on git metadata, but on content_pages
      @crdate = content_pages.map(&:crdate).min
      @lastmod = content_pages.map(&:lastmod).max
    end

    def fillindex(content_pages, stmap)
      st = Struct.new(:title, :content_pages, :begints, :endts)
      content_pages = content_pages.sort_by { |cp| -cp.crdate.to_i }
      @subtopics = content_pages.group_by(&:subtopic).map do |subtop, grp|
        st.new(stmap[subtop], grp, grp.last.crdate, grp.first.crdate)
      end
      update_crdate_lastmod content_pages if content_pages.any?
    end
  end

  # For .clay files
  class ContentPage < IndexPage
    attr_accessor :subtopic

    def initialize(filename, git)
      super
      # There cannot be ContentPages nested under 'index'
      @topic, @subtopic, = @filename.split '/', 3
      @subtopic = nil if @subtopic.end_with?('.clay')
      @permalink = @filename.split('.clay').first
      @target = "#{@permalink}.html"
    end
  end

  def self.dirty_pages_from_mod(index_files, content_files)
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
    [dirty_index_pages, dirty_content_pages]
  end

  def self.dirty_pages(index_files, content_files, is_aggressive)
    # Check the git index exactly once to determine dirty files
    git = Git::Info.new @config.tzmap

    # An index_file that is added (or deleted) should mark all index_files as dirty
    if git.any_added?(index_files) || git.template_changed? || is_aggressive
      dirty_index_pages = index_files.map { |filename| IndexPage.new filename, git }
      dirty_content_pages = content_files.map { |filename| ContentPage.new filename, git }
    else
      dirty_index_pages, dirty_content_pages = dirty_pages_from_mod(index_files, content_files)
    end

    [dirty_index_pages, dirty_content_pages, git]
  end

  def self.unhidden_content_files(content_files)
    content_files.reject do |cf|
      @config.hidden.any? { |hidden_entry| "#{hidden_entry}.clay" == cf }
    end
  end

  # Return index_pages and content_pages to generate; we work with
  # content_files and index_files, because converting them to Page
  # objects prematurely will result in unnecessary log --follows
  def self.pages_to_regenerate(index_files, content_files, is_aggressive)
    puts "[#{'GIT'.green}]: Digging the git object store"
    dirty_index_pages, dirty_content_pages, git = dirty_pages index_files, content_files, is_aggressive

    # Now, set the indexfill for index_pages by looking at all the content_files
    # corresponding to a dirty index_page.
    # Additionally, reject hidden content_files from the corresponding indexfill
    dirty_index_pages.each do |dip|
      content_pages = unhidden_content_files(content_files).select { |cf| cf.split('/', 2).first == dip.permalink }
                                                           .map { |cf| ContentPage.new cf, git }
      dip.fillindex content_pages, @config.stmap
    end
    [dirty_index_pages + dirty_content_pages, git]
  end

  def self.generate_sitemap(all_pages)
    SitemapGenerator::Sitemap.default_host = "https://#{@config.sitename}"
    SitemapGenerator::Sitemap.public_path = '.'
    SitemapGenerator::Sitemap.create do
      all_pages.each do |page|
        add page.permalink, lastmod: page.lastmod
      end
    end
  end

  def self.index_content_files(all_files)
    # index_files are files ending in '.index.clay' and 'index.clay'
    # content_files are all other files; topics is the list of topics: we need it for the sidebar
    index_files = ['index.clay'] + all_files.select { |file| /\.index\.clay$/ =~ file }
    content_files = all_files - index_files
    all_topics = Util.lex_sort(index_files).map { |file| file.split('.index.clay').first }
    topics = all_topics.reject do |entry|
      @config.hidden.any? { |hidden_entry| hidden_entry == entry }
    end

    # Look for stray files.  All content_files are nested within directories
    content_files
      .reject { |file| all_topics.include? file.split('/').first }
      .each do |stray|
      content_files -= [stray]
      puts "[#{'WARN'.red}] #{stray} is a stray file or directory; ignored"
    end

    [index_files, content_files, topics]
  end

  # Process with claytext first, and produce HTML files, to be consumed by MathJaX
  def self.generate_html(genpages, topics)
    progress = ProgressBar.create(title: "[#{'HTML'.green}]", total: genpages.length)
    genpages.each { |page| page.render topics, @config.template; progress.increment }

    # Process the generated HTML files using MathJaX
    puts "[#{'TeX'.green}]: Rendering math"
    targets = genpages.map(&:target).join ' '
    `npm run --silent jax -- #{targets}`
  end

  def self.minify_design
    puts "[#{'NPM'.green}]: Minifying js and css"
    `npm run --silent minify`
  end

  def self.generate_site(genpages, topics, is_aggressive)
    # Generate the HTML
    generate_html genpages, topics if genpages.any?

    # Finally, minify the design, and regenerate the sitemap
    minify_design if @git.design_changed? || is_aggressive
    generate_sitemap genpages if is_aggressive
  end

  def self.main(is_aggressive: false)
    # Only operate on git repositories
    toplevel = `git rev-parse --show-toplevel`.strip
    abort "[#{'ERR'.red}] Not a clayoven project" if toplevel.empty? || (!File.directory? "#{toplevel}/.clayoven")
    Dir.chdir(toplevel) do
      # Write out template files, if necessary
      @config = Config::Data.new

      # Collect the list of files from a directory listing
      all_files = Util.ls_files

      # From all_files, get the list of index_files, content_files, and topics
      index_files, content_files, topics = index_content_files all_files

      # Get a list of pages to regenerate
      genpages, @git = pages_to_regenerate index_files, content_files, is_aggressive

      # Generate the entire site
      is_aggressive = true if @git.template_changed?
      generate_site genpages, topics, is_aggressive if genpages.any?
    end
  end
end
