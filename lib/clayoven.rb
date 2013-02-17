$:.unshift File.dirname(__FILE__)

require 'slim'
require 'clayoven/config'
require 'clayoven/claytext'
require 'clayoven/httpd'
require 'clayoven/imapd'

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

    def render(topics)
      @topics = topics
      @paragraphs = ClayText.process! @body
      Slim::Engine.set_default_options pretty: true, sort_attrs: false
      rendered = Slim::Template.new { IO.read("design/template.slim") }.render(self)
      File.open(@target, mode="w") { |targetio|
        nbytes = targetio.write(rendered)
        puts "[GEN] #{@target} (#{nbytes} bytes out)"
      }
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
                 [".", "..", ".clayoven", "design"]).reject { |entry|
      config.ignore.any? { |pattern| %r{#{pattern}} =~ entry }
    }

    abort "error: design/template.slim file not found; aborting" if not
      Dir.entries("design").include? "template.slim"

    index_files = ["index"] + all_files.select { |file| /\.index$/ =~ file }
    content_files = all_files - index_files
    topics = index_files.map { |file| file.split(".index")[0] }.uniq

    # Next, look for stray files
    (content_files.reject { |file| topics.include? (file.split(":", 2)[0]) })
      .each { |stray_entry|
      content_files = content_files - [stray_entry]
      puts "warning: #{stray_entry} is a stray file or directory; ignored"
    }

    index_pages = index_files.map { |filename| IndexPage.new(filename) }
    content_pages = content_files.map { |filename| ContentPage.new(filename) }

    # First, fill in all the page attributes
    (index_pages + content_pages).each { |page|
      page.title, page.body = (IO.read page.filename).split("\n\n", 2)
    }

    # Compute the indexfill for indexes
    topics.each { |topic|
      topic_index = index_pages.select { |page| page.topic == topic }[0]
      topic_index.indexfill = content_pages.select { |page|
        page.topic == topic }.sort { |a, b| b.timestamp <=> a.timestamp }
    }

    (index_pages + content_pages).each { |page| page.render topics }
  end
end
