require 'net/imap'
require_relative 'config'

module Clayoven
  # `clayoven impad` essentially calls Imapd.poll
  # (but also calls Clayoven.main)
  module Imapd
    # Initialites a connection to the IMAP server, and fetches new
    # messages.
    #
    # Returns an unnamed Struct with :filename, :date, :msgid fields
    def self.poll
      config = Clayoven::ConfigData.new
      abort "error: #{config.rcpath} not found; aborting" if not config.rc
      mails = []
      server = Net::IMAP.new(config.rc["server"],
                             {:port => config.rc["port"], :ssl => config.rc["ssl"]})
      trap(:INT) { exit 1 }
      server.login config.rc["username"], config.rc["password"]
      puts "[NOTE] LOGIN successful"
      server.examine "INBOX"
      server.search(["ALL"]).each do |id|
        message = server.fetch(id, ["ENVELOPE", "RFC822.TEXT"])[0]

        # This block is only run if we receive email from the trusted
        # sender (a configuration variable).
        trustmailbox, trusthost = config.rc["trustfrom"].split("@")
        if message.attr["ENVELOPE"].sender[0].mailbox == trustmailbox and
            message.attr["ENVELOPE"].sender[0].host == trusthost
          date = message.attr["ENVELOPE"].date
          msgid = message.attr["ENVELOPE"].message_id
          title, filename = message.attr["ENVELOPE"].subject.split(" # ")
          next if File.exists? filename
          File.open(filename, "w") do |targetio|
            targetio.write([title, message.attr["RFC822.TEXT"].delete("\r")].join "\n\n")
          end
          mails << Struct.new(:filename, :date, :msgid).new(filename, date, msgid)
        end
      end
      server.disconnect
      mails
    end
  end
end
