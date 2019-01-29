require 'slim'
require_relative 'clayoven/config'
require_relative 'clayoven/clayfeed'
require_relative 'clayoven/claytext'
require_relative 'clayoven/httpd'

# Sorts a list of filenames lexicographically, but for 'index', which is first
def lex_sort files
  ['index'] + (files.reject { |f| f == 'index'}).sort
end

module Clayoven
  class Page
    attr_accessor :filename, :permalink, :timestamp, :title, :topic, :body,
    :pubdate, :authdate, :paragraphs, :target, :indexfill, :topics

    # Intialize with filename and authored dates from git
    def initialize filename
      @filename = filename
      @dates = `git log --follow --format="%aD" #{@filename}`.split "\n"
      @pubdate = @dates.first.split(' ')[0..3].join(' ')
      @authdate = @dates.last.split(' ')[0..3].join(' ')
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
    attr_accessor :unixdate

    def initialize filename
      super
      @topic, _ = @filename.split '/', 2
      @target = "#{@filename}.html"
      @permalink = @filename
      @indexfill = nil
      @unixdate = `git log --follow --format="%at" #{@filename} | tail -n 1`
    end
  end

  def self.main
    abort 'error: index file not found; aborting' unless File.exists? 'index'

    config = Clayoven::ConfigData.new
    all_files = Dir.glob('**/*').reject { |entry| File.directory? entry }.reject { |entry| Regexp.union(/design\/.*/, /.clayoven\/.*/) =~ entry}.reject do |entry|
      config.ignore.any? { |pattern| %r{#{pattern}} =~ entry }
    end

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
    (content_files.reject { |file| topics.include? file.split('/', 2)[0] }).each do |stray_entry|
      content_files = content_files - [stray_entry]
      puts "[WARN] #{stray_entry} is a stray file or directory; ignored"
    end

    # Turn index_files and content_files into objects
    index_pages = (lex_sort index_files).map { |filename| IndexPage.new filename }
    content_pages = content_files.map { |filename| ContentPage.new filename }.sort_by { |cp| cp.unixdate }.reverse!

    # Update topics to be a sorted Array extracted from index_pages.
    topics = index_pages.reject { |page| page.topic == '404' }.map { |page| page.topic }

    # Fill in page.title and page.body by reading the file
    (index_pages + content_pages).each do |page|
      page.title, page.body = (IO.read page.filename).split "\n\n", 2
    end

    # Compute the indexfill for indexes
    topics.each do |topic|
      topic_index = index_pages.select { |page| page.topic == topic }.first
      topic_index.indexfill = content_pages.select { |page| page.topic == topic }
    end

    (index_pages + content_pages).each { |page| page.render topics }
  end
end
