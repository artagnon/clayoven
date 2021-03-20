# The data from .clayoven/config
class Clayoven::Config
  # The sitename excluding the 'https://' prefix
  attr_accessor :sitename

  # A list of hidden entries
  attr_accessor :hidden

  # A timezone mapper of the form {'+0000' => 'London'}
  attr_accessor :tzmap

  # A subtopic mapper of the form {'inf' => '∞-categories'}
  attr_accessor :stmap

  # A template .slim file read out from disk
  attr_accessor :template

  TZ_DEFAULT = <<-'EOF'.freeze
  +0000 UTC
  EOF

  SUBTOPIC_DEFAULT = <<-'EOF'.freeze
  [subtopic directory] [subtopic title]
  EOF

  SLIM_DEFAULT = <<-'EOF'.freeze
  EOF

  # Creates file at path, if it doesn't exist, with template text
  def create_template(path, template)
    components = path.split '/'
    Dir.mkdir components[0] if components.length == (2) && !(Dir.exist? components[0])
    if File.exist?(path)
      IO.read(path).split "\n"
    else
      File.open(path, 'w') { |io| io.write template }
      [template]
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
