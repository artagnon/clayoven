module Config
  SLIM_DEFAULT = <<-'EOF'
  doctype html
  html
    head
      title clayoven: #{permalink}
    body
      div id="main"
        h1 #{title}
        time #{authdate.strftime("%F")}
        - paragraphs.each do |paragraph|
          - if paragraph.is_plain?
            p
              == paragraph.contents.join "\n"
      div id="sidebar"
        ul
          - if topics
            - topics.each do |topic|
              li
                a href="/#{topic}"
                  = topic
  EOF

  INDEX_DEFAULT = <<-'EOF'
  clayoven

  https://github.com/artagnon/clayoven/blob/master/README.md should have you covered.
  Enjoy using clayoven!
  EOF

  TZ_DEFAULT = <<-'EOF'
  +0000 UTC
  EOF

  class Data
    attr_accessor :sitename, :hidden, :tzmap

    # Creates file at path, if it doesn't exist, with template text
    def create_template(path, template)
      components = path.split "/"
      if components.length == 2
        Dir.mkdir components[0] unless Dir.exists? components[0]
      end
      if File.exists?(path)
        IO.read(path).split "\n"
      else
        File.open(path, "w") { |io| io.write template }
        [template]
      end
    end

    def initialize
      @sitename = create_template(".clayoven/sitename", "clayoven.io").first
      @hidden = create_template ".clayoven/hidden", ["404.index.clay"].join("\n")
      @tzmap = (create_template ".clayoven/tz", TZ_DEFAULT).map { |l| l.split(" ", 2) }.to_h
      create_template "design/template.slim", SLIM_DEFAULT
      create_template "index.clay", INDEX_DEFAULT
    end
  end
end
