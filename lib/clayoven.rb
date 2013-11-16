$:.unshift __dir__

require 'slim'
require 'clayoven/config'
require 'clayoven/claytext'
require 'clayoven/httpd'

# Sorts a list of filenames by first-committed time.
def git_sort files, reverse_p
  reverse = ''
  reverse = '--reverse' if reverse_p
  `git log #{reverse} --format=%H --name-status --diff-filter=A -- #{files.join ' '} | grep ^A | cut -f2`.split "\n"
end

module Clayoven
  class Page
    attr_accessor :filename, :permalink, :timestamp, :title, :topic, :body,
    :pubdate, :paragraphs, :target, :indexfill, :topics

    # Writes out HTML pages.  Takes a list of topics to render
    #
    # Prints a '[GEN]' line for every file it writes out.
    def render topics
      @topics = topics
      @paragraphs = ClayText.process @body
      Slim::Engine.set_default_options pretty: true, sort_attrs: false
      rendered = Slim::Template.new { IO.read 'design/template.slim' }.render self
      File.open(@target, mode = 'w') do |targetio|
        nbytes = targetio.write rendered
        puts "[GEN] #{@target} (#{nbytes} bytes out)"
      end
    end
  end

  class IndexPage < Page
    def initialize filename
      @filename = filename
      if @filename == 'index'
        @permalink = @filename
      else
        @permalink = filename.split('.index')[0]
      end
      @topic = @permalink
      @target = "#{@permalink}.html"
    end
  end

  class ContentPage < Page
    attr_accessor :pub_date

    def initialize filename
      @filename = filename
      @topic, @permalink = @filename.split ':', 2
      @target = "#{@permalink}.html"
      @indexfill = nil
    end
  end

  def self.main
    abort 'error: index file not found; aborting' unless File.exists? 'index'

    config = Clayoven::ConfigData.new
    all_files = (Dir.entries('.') -
                 ['.', '..', '.clayoven', 'design']).reject do |entry|
      config.ignore.any? { |pattern| %r{#{pattern}} =~ entry }
    end

    # We must have a 'design' directory.  I don't plan on making this
    # a configuration variable.
    unless Dir.entries('design').include? 'template.slim'
      abort 'error: design/template.slim file not found; aborting'
    end

    # index_files are files ending in '.index' and 'index'
    # content_files are all other files (we've already applied ignore)
    # topics is the list of topics.  We need it for the sidebar
    index_files = ['index'] + all_files.select { |file| /\.index$/ =~ file }
    content_files = all_files - index_files
    topics = index_files.map { |file| file.split('.index')[0] } + ['hidden']

    # Look for stray files.  All content_files that don't have a valid
    # topic before ":" (or don't have ";" in their filename at all)
    (content_files.reject { |file| topics.include? file.split(':', 2)[0] })
      .each do |stray_entry|
      content_files = content_files - [stray_entry]
      puts "warning: #{stray_entry} is a stray file or directory; ignored"
    end

    # Turn index_files and content_files into objects
    index_pages = (git_sort index_files, true).map { |filename| IndexPage.new filename }
    content_pages = (git_sort content_files, false).map { |filename| ContentPage.new filename }

    # Update topics to be a sorted Array extracted from index_pages.
    # It'll automatically exclude "hidden".
    topics = index_pages.map { |page| page.topic }

    # Fill in page.title and page.body by reading the file
    (index_pages + content_pages).each do |page|
      page.title, page.body = (IO.read page.filename).split "\n\n", 2
    end

    # Fill in page.pubdate by asking git
    content_pages.each do |page|
      page.pubdate = `git log --reverse --format="%aD" #{page.filename} | head -n 1`.split(' ')[0..3].join(' ')
    end

    # Compute the indexfill for indexes
    topics.each do |topic|
      topic_index = index_pages.select { |page| page.topic == topic }[0]
      topic_index.indexfill = content_pages.select { |page| page.topic == topic }
    end

    (index_pages + content_pages).each { |page| page.render topics }
  end
end
