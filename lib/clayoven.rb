$:.unshift __dir__

require 'slim'
require 'clayoven/config'
require 'clayoven/claytext'
require 'clayoven/httpd'

# Figures out the timestamp of the commit that introduced a specific
# file.  If the file hasn't been checked into git yet, return the
# current time.
def when_introduced(filename)
  timestamp = `git log --reverse --pretty="%at" #{filename} 2>/dev/null | head -n 1`.strip
  if timestamp == ""
    Time.now
  else
    Time.at(timestamp.to_i)
  end
end

module Clayoven
  class Page
    attr_accessor :filename, :permalink, :timestamp, :title, :topic, :body,
    :paragraphs, :target, :indexfill, :topics

    # Writes out HTML pages.  Takes a list of topics to render
    #
    # Prints a "[GEN]" line for every file it writes out.
    def render(topics)
      @topics = topics
      @paragraphs = ClayText.process! @body
      Slim::Engine.set_default_options pretty: true, sort_attrs: false
      rendered = Slim::Template.new { IO.read("design/template.slim") }.render(self)
      File.open(@target, mode="w") do |targetio|
        nbytes = targetio.write(rendered)
        puts "[GEN] #{@target} (#{nbytes} bytes out)"
      end
    end
  end

  class IndexPage < Page
    def initialize(filename)
      @filename = filename
      if @filename == "index"
        @permalink = @filename
      else
        @permalink = filename.split(".index")[0]
      end
      @topic = @permalink
      @target = "#{@permalink}.html"
      @timestamp = when_introduced @filename
    end
  end

  class ContentPage < Page
    attr_accessor :pub_date

    def initialize(filename)
      @filename = filename
      @topic, @permalink = @filename.split(":", 2)
      @target = "#{@permalink}.html"
      @indexfill = nil
      @timestamp = when_introduced @filename
    end
  end

  def self.main
    abort "error: index file not found; aborting" if not File.exists? "index"

    config = Clayoven::ConfigData.new
    all_files = (Dir.entries(".") -
                 [".", "..", ".clayoven", "design"]).reject do |entry|
      config.ignore.any? { |pattern| %r{#{pattern}} =~ entry }
    end

    # We must have a "design" directory.  I don't plan on making this
    # a configuration variable.
    if not Dir.entries("design").include? "template.slim"
      abort "error: design/template.slim file not found; aborting"
    end

    # index_files are files ending in ".index" and "index"
    # content_files are all other files (we've already applied ignore)
    # topics is the list of topics.  We need it for the sidebar
    index_files = ["index"] + all_files.select { |file| /\.index$/ =~ file }
    content_files = all_files - index_files
    topics = index_files.map { |file| file.split(".index")[0] } + ["hidden"]

    # Look for stray files.  All content_files that don't have a valid
    # topic before ":" (or don't have ";" in their filename at all)
    (content_files.reject { |file| topics.include? (file.split(":", 2)[0]) })
      .each do |stray_entry|
      content_files = content_files - [stray_entry]
      puts "warning: #{stray_entry} is a stray file or directory; ignored"
    end

    # Turn index_files and content_files into objects
    index_pages = index_files.map { |filename| IndexPage.new(filename) }
    content_pages = content_files.map { |filename| ContentPage.new(filename) }

    # Update topics to be a sorted Array extracted from index_pages.
    # It'll automatically exclude "hidden".
    topics = index_pages.sort { |a, b| a.timestamp <=> b.timestamp }
      .map { |page| page.topic }

    # Fill in page.title and page.body by reading the file
    (index_pages + content_pages).each do |page|
      page.title, page.body = (IO.read page.filename).split("\n\n", 2)
    end

    # Compute the indexfill for indexes
    topics.each do |topic|
      topic_index = index_pages.select { |page| page.topic == topic }[0]
      topic_index.indexfill = content_pages.select { |page|
        page.topic == topic }.sort { |a, b| b.timestamp <=> a.timestamp }
    end

    (index_pages + content_pages).each { |page| page.render topics }
  end
end
