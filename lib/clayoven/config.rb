# \Clayoven Configuration
#
# \Clayoven can be configured using files `.clayoven/{sitename, hidden, tz, subtopics}`
# at the toplevel directory.
#
# If a certain configuration file doesn't exist, we automatically create a default one.
class Clayoven::Config
  # The public URL of the website excluding the 'https://' prefix
  attr_accessor :sitename

  # A list of Clayoven::Toplevel::ContentPage#permalink entries,
  # not to be displayed when generating the corresponding Clayoven::Toplevel::IndexPage
  attr_accessor :hidden

  # A timezone mapper of the form {'+0000' => 'London'}
  # Exposed as Clayoven::Toplevel::Page#locations
  attr_accessor :tzmap

  # A subtopic mapper of the form {'inf' => '∞-categories'}
  # Exposed as Clayoven::Toplevel::IndexPage#subtopics
  attr_accessor :stmap

  # A .slim file read out from disk; hard-coded to the contents of `design/template.slim`
  attr_accessor :template

  # Format: [(+|-)\d{4}] [String]
  TZ_DEFAULT = <<-'EOF'.freeze
  +0000 UTC
  EOF

  # Format: [Subdirectory name without spaces] [Subdirectory title]
  SUBTOPIC_DEFAULT = <<-'EOF'.freeze
  [subtopic directory] [subtopic title]
  EOF

  # Format: The contents of a valid template file
  # A more full-featured one is generated by `clayoven init`
  SLIM_DEFAULT = <<-'EOF'.freeze
  doctype html
  html lang="en"
    head
      title clayoven: #{permalink}
    body
      div id="main"
        h1 = title
        time = crdate.strftime("%F")
        - paragraphs.each do |paragraph|
          p == paragraph.to_s
      div id="sidebar"
        ul
          - if topics
            - topics.each do |topic|
              li
                a href="/#{topic}" = topic
  EOF

  # Creates file at path, if it doesn't exist, initializes with default
  def create_template(path, default)
    components = path.split '/'
    Dir.mkdir components[0] if components.length == (2) && !(Dir.exist? components[0])
    if File.exist?(path)
      IO.read(path).split "\n"
    else
      File.open(path, 'w') { |io| io.write default }
      [default]
    end
  end

  # Initialize our config strings and hashtables based on some sane defaults
  def initialize
    @sitename = create_template('.clayoven/sitename', 'clayoven.io').first
    @hidden = create_template '.clayoven/hidden', %w[404 scratch].join("\n")
    @tzmap = (create_template '.clayoven/tz', TZ_DEFAULT).map { |l| l.split(' ', 2) }.to_h
    @stmap = (create_template '.clayoven/subtopic', SUBTOPIC_DEFAULT).map { |l| l.split(' ', 2) }.to_h
    @stmap.default_proc = proc { |h, k| h[k] = k }
    @template = (create_template 'design/template.slim', SLIM_DEFAULT).join "\n"
  end
end
