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
  class Page
    attr_accessor :filename, :permalink, :timestamp, :title, :topic, :body,
    :pubdateobj, :authdateobj, :paragraphs, :target, :indexfill, :topics

    # Intialize with filename and authored dates from git
    def initialize filename
      @filename = filename
      @dates = `git log --follow --format="%aD" #{@filename}`.split "\n"
      pubdate = @dates.first
      @pubdateobj = Time.parse(pubdate)
      authdate = @dates.last
      @authdateobj = Time.parse(authdate)
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
    def initialize filename
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
    def initialize filename
      super
      @topic, _ = @filename.split '/', 2
      @target = "#{@filename}.html"
      @permalink = @filename
      @indexfill = nil
    end
  end

  # Populate the indexfill field in each topic
  def self.indexfill topics, index_pages, content_pages
    topics.each do |topic|
      topic_index = index_pages.select { |page| page.topic == topic }.first
      topic_index.indexfill = content_pages.select { |page| page.topic == topic }
    end
  end

  def self.page_objects index_files, content_files
    index_pages = (lex_sort index_files).map { |filename| IndexPage.new filename }
    content_pages = content_files
      .map { |filename| ContentPage.new filename }
      .sort_by { |cp| [-cp.authdateobj.to_i, cp.filename] }
    return index_pages, content_pages
  end

  def self.generate_sitemap all_pages
    SitemapGenerator::Sitemap.default_host = 'https://artagnon.com'
    SitemapGenerator::Sitemap.public_path = '.'
    SitemapGenerator::Sitemap.create do
      all_pages.each do |page|
        add page.permalink, :lastmod => page.pubdateobj
      end
    end
  end

  def self.main
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
    topics = (index_files - ['404']).map { |file| file.split('.index').first }

    # Look for stray files.  All content_files are nested within directories
    content_files
      .reject { |file| topics.include? file.split('/', 2)[0] }
      .each do |stray|
      content_files = content_files - [stray]
      puts "[WARN] #{stray} is a stray file or directory; ignored"
    end

    # Turn index_files and content_files into objects
    index_pages, content_pages = page_objects index_files, content_files

    # Update topics to be a sorted Array extracted from index_pages.
    topics = index_pages.reject { |page| page.topic == '404' }.map { |page| page.topic }

    # Compute the indexfill for indexes
    indexfill topics, index_pages, content_pages

    # Operations on all_pages follow
    all_pages = index_pages + content_pages
    
    # Set the title and body for the render function
    all_pages.each do |page|
      page.title, page.body = (IO.read page.filename).split "\n\n", 2
    end

    # Produce the final HTML using slim
    all_pages.each { |page| page.render topics }
    generate_sitemap all_pages
  end
end
