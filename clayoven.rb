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

  # Next, look for stray files
  index_files = ["index"] + all_files.select { |file| /\.index/ =~ file }
  topics = index_files.map { |file| file.split(".index")[0] }
  content_files = all_files - index_files
  (content_files.reject { |file| topics.include? (file.split(":", 2)[0]) })
    .each { |stray_file|
    content_files = content_files - [stray_file]
    puts "warning: #{stray_file} is a stray file; ignored"
  }

  # Generate all the pages
  (index_files + content_files).each { |file|
    if file == "index"
      target = "index.html"
      permalink = file
      template = IO.read("design/template.index.html")
    elsif index_files.include? file
      target = file.sub(".index", ".html")
      permalink = file.split(".index")[0]
      template = IO.read("design/template.index.html")
    else
      target = "#{file.split(':', 2)[1]}.html"
      permalink = file.split(":", 2)[0]
      template = IO.read("design/template.html")
    end
    content = escape_htmlspecialchars(IO.read file)
    title, rest = content.split("\n\n", 2)
    begin
      # Optional footer
      body, partial_footer = rest.split("\n\n[1]: ", 2)
      footer = "\n\n[1]: #{partial_footer}"
    rescue
    end
    anchor_footerlinks footer if footer
    ["permalink", "title", "body", "footer"].each { |template_var|
      template.gsub!("\{% #{template_var} %\}", eval(template_var))
    }
    File.open(target, mode="w") { |targetio|
      nbytes = targetio.write(template)
      puts "[GEN] #{target} (#{nbytes} bytes out)"
    }
  }
end

main
