require 'rss'
require_relative 'config'

# Renders a static XML feed
module ClayFeed

  def self.render!(content_pages)
    return unless not content_pages.empty?

    config = Clayoven::ConfigData.new
    abort "error: #{config.rcpath} not found; aborting" if not config.rc

    content_pages.sort! { |a, b| b.timestamp <=> a.timestamp }

    rss = RSS::Maker.make("atom") do |maker|
      maker.channel.author = config.rc['rss-author']
      maker.channel.updated = content_pages[0].timestamp
      maker.channel.about = config.rc['rss-about-page']
      maker.channel.title = config.rc['rss-title']

      content_pages.each do |page|
        maker.items.new_item do |item|
          item.link = "#{config.rc["rss-blog-root"]}/#{page.target}"
          item.title = page.title
          item.updated = page.timestamp
        end
      end
    end

    rss_filename = "#{config.rc['rss-filename']}.rss"
    File.open(rss_filename, mode='w') do |io|
      nbytes = io.write(rss.to_s)
      puts "[GEN] #{rss_filename} (#{nbytes} bytes out)"
    end
  end
end
