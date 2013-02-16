require 'net/imap'
require_relative 'config'

class Mail
  attr_accessor :filename, :date, :msgid

  def initialize(filename, date, msgid)
    @filename = filename
    @date = date
    @msgid = msgid
  end
end

class Imapd
  def self.poll
    config = ConfigData.new
    if not config.rc
      puts "error: #{config.rcpath} not found; aborting"
      exit 1
    end
    mails = []
    server = Net::IMAP.new(config.rc["server"],
                           {:port => config.rc["port"], :ssl => config.rc["ssl"]})
    trap(:INT) { exit 1 }
    server.login config.rc["username"], config.rc["password"]
    puts "[NOTE] LOGIN successful"
    server.examine "INBOX"
    server.search(["ALL"]).each { |id|
      message = server.fetch(id, ["ENVELOPE", "RFC822.TEXT"])[0]
      if message.attr["ENVELOPE"].sender[0].mailbox == "artagnon" and
          message.attr["ENVELOPE"].sender[0].host == "gmail.com" and
          message.attr["ENVELOPE"].sender[0].name == "Ramkumar Ramachandra"
        date = message.attr["ENVELOPE"].date
        msgid = message.attr["ENVELOPE"].message_id
        title, filename = message.attr["ENVELOPE"].subject.split(" # ")
        next if File.exists? filename
        File.open(filename, "w") { |targetio|
          targetio.write([title, message.attr["RFC822.TEXT"].delete("\r")].join "\n\n")
        }
        mails << Mail.new(filename, date, msgid)
      end
    }
    server.disconnect
    mails
  end
end
