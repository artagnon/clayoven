class Page
  attr_accessor :filename, :permalink, :title, :topic, :body, :target
end

class IndexPage < Page
  attr_accessor :index_fill

  def initialize(filename)
    @filename = filename
    if @filename == "index"
      @permalink = @filename
    else
      @permalink = filename.split(".index")[0]
    end
    @topic = @permalink
    @target = "#{@permalink}.html"
  end
  def template
    IO.read("design/template.index.html")
  end
end

class ContentPage < Page
  attr_accessor :pub_date

  def initialize(filename)
    @filename = filename
    @topic, @permalink = @filename.split(":", 2)
    @target = "#{@permalink}.html"
  end
  def template
    IO.read("design/template.html")
  end
end

def escape_htmlspecialchars(content)
  # see: http://php.net/htmlspecialchars
  replaces = {
    "&" => "&amp;",
    "\"" => "&quot;",
    "'" => "&apos;",
    "<" => "&lt;",
    ">" => "&gt;"
  }
  replaces.each { |key, value| content.gsub!(key, value) }
  content
end

def anchor_footerlinks(footer)
  footer.gsub!(/^(\[\d+\]:) (.*)/, '\1 <a href="\2">\2</a>')
end

def main
  # First, make sure that the required files are present
  all_files = (Dir.entries(".") - [".", "..", "design", ".git"]).reject { |file|
    /\.html$/ =~ file
  }
  if not all_files.include? "index"
    puts "error: index file not found; aborting"
    exit 1
  end

  ["template.index.html", "template.html"].each { |file|
    if not Dir.entries("design").include? file
      puts "error: design/#{file} file not found; aborting"
      exit 1
    end
  }

  index_files = ["index"] + all_files.select { |file| /\.index$/ =~ file }
  content_files = all_files - index_files
  index_pages = index_files.map { |file| IndexPage.new(file) }
  content_pages = content_files.map { |file| ContentPage.new(file) }
  topics = index_files.map { |file| file.split(".index")[0] }

  # Next, look for stray files
  (content_files.reject { |file| topics.include? (file.split(":", 2)[0]) })
    .each { |stray_file|
    puts "warning: #{stray_file} is a stray file; ignored"
  }

  # First, fill in all the page attributes
  (index_pages + content_pages).each { |page|
    page.content = escape_htmlspecialchars(IO.read file)
    page.title, page.body = content.split("\n\n", 2)
    anchor_footerlinks page.body
  }

  # Compute sidebar
  sidebar = topics.map { |topic|
    "<li><a href=\"#{topic}\">#{topic}/</a></li>" }.join("\n")

  # Compute the indexfill for indexes
  flist = content_files.select { |file| file.start_with? "#{permalink}:" }
  topics.each { |topic|
    topic_index = index_pages.select { |page| page.topic == topic }[0] # there is only one
    topic_index.indexfill = content_pages.select { |page| page.topic == topic }
  indexfill = flist.map { |file| file.split("#{permalink}:")[1] }.map {
    |link| "<li><a href=\"#{link}\">#{link}</a></li>" }.join("\n") if flist

  (index_pages + content_pages.each { |page|
    template_vars = ["permalink", "title", "body", "sidebar"]
    ["indexfill"].each { |optional_field|
      if eval(page.optional_field)
        template_vars = template_vars + [optional_field]
      else
        template.gsub!("\{% #{optional_field} %\}", "")
      end
    }
    template_vars.each { |template_var|
      template.gsub!("\{% #{template_var} %\}", eval(template_var))
    }
    File.open(target, mode="w") { |targetio|
      nbytes = targetio.write(template)
      puts "[GEN] #{target} (#{nbytes} bytes out)"
    }
  }
end

main
