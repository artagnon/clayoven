require 'yaml'
require 'net/imap'

config_file = File.expand_path("~/.clayovenrc")
if not File.exist? config_file
  puts "error: #{config_file} not found; aborting"
  exit 1
end
config = YAML.load_file(config_file)
server = Net::IMAP.new(config["server"],
                       {:port => config["port"], :ssl => config["ssl"]})
server.login(config["username"], config["password"])
server.examine("INBOX")
server.search(["ALL"]).each { |message_id|
  envelope = server.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
  puts "#{message_id}:: envelope.from[0].name}: #{envelope.subject}"
}
