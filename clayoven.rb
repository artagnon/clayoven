require 'slim'

class Page
  attr_accessor :filename, :permalink, :title, :topic, :body, :template, :target, :topics

  def render(topics)
    self.topics = topics
    rendered = Slim::Template.new { @template }.render(self)
    File.open(@target, mode="w") { |targetio|
      nbytes = targetio.write(rendered)
      puts "[GEN] #{@target} (#{nbytes} bytes out)"
    }
  end
end

class IndexPage < Page
  attr_accessor :indexfill

  def initialize(filename)
    @filename = filename
    if @filename == "index"
      @permalink = @filename
    else
      @permalink = filename.split(".index")[0]
    end
    @topic = @permalink
    @target = "#{@permalink}.html"
    @template = IO.read("design/template.index.slim")
  end
end

class ContentPage < Page
  attr_accessor :pub_date

  def initialize(filename)
    @filename = filename
    @topic, @permalink = @filename.split(":", 2)
    @target = "#{@permalink}.html"
    @template = IO.read("design/template.slim")
  end
end

def anchor_footerlinks(footer)
  footer.gsub!(/^(\[\d+\]:) (.*)/, '\1 <a href="\2">\2</a>')
end

def main
  # First, make sure that the required files are present
  all_files = (Dir.entries(".") - [".", "..", "design", ".git",
                                   ".gitignore"]).reject { |file|
    /\.html$/ =~ file
  }
  if not all_files.include? "index"
    puts "error: index file not found; aborting"
    exit 1
  end

  ["template.index.slim", "template.slim"].each { |file|
    if not Dir.entries("design").include? file
      puts "error: design/#{file} file not found; aborting"
      exit 1
    end
  }

  index_files = ["index"] + all_files.select { |file| /\.index$/ =~ file }
  content_files = all_files - index_files
  index_pages = index_files.map { |filename| IndexPage.new(filename) }
  content_pages = content_files.map { |filename| ContentPage.new(filename) }
  topics = index_files.map { |file| file.split(".index")[0] }.uniq

  # Next, look for stray files
  (content_files.reject { |file| topics.include? (file.split(":", 2)[0]) })
    .each { |stray_file|
    puts "warning: #{stray_file} is a stray file; ignored"
  }

  # First, fill in all the page attributes
  (index_pages + content_pages).each { |page|
    page.title, page.body = (IO.read page.filename).split("\n\n", 2)
    anchor_footerlinks page.body
  }

  # Compute the indexfill for indexes
  topics.each { |topic|
    topic_index = index_pages.select { |page| page.topic == topic }[0] # there is only one
    topic_index.indexfill = content_pages.select { |page| page.topic == topic }
  }

  (index_pages + content_pages).each { |page| page.render topics }
end

main
