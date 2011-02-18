require 'open-uri'
require 'feed_yamlizer'
require 'vnews/autodiscoverer'
require 'vnews/sql'

class Vnews
  class Feed
    include Autodiscoverer

    def initialize(url, folder)
      @url = url
      @folder = folder
      @sqlclient = Vnews::Sql.new
    end

    def get_feed(feed_url)
      feed_url = repair feed_url
      response = open(feed_url)
      xml = response.read
      # puts response.last_modified
      $stderr.puts response.content_type
      $stderr.puts response.charset
      charset = response.charset || "ISO-8859-1"

      if response.content_type !~ /xml/
        log "Can't find feed at #{feed_url}\nAttempting autodiscovery"
        feed_url = auto_discover(feed_url)
        if feed_url 
          return get_feed(feed_url)
        else
          log "No feed URL found at #{feed_url}"
          nil
        end
      end
      $stderr.puts "Running"
      feed_yaml = FeedYamlizer.run(xml, charset)
    end


    # input is a hash
    def fetch
      f = get_feed @url
      return unless f
      @sqlclient.insert_feed(f[:meta][:title], f[:meta][:link], @folder)
      f[:items].each do |item|
        if item[:guid].nil? || item[:guid].strip == ''
          item[:guid] = f[:meta][:link] + Time.now.to_i
        end
        @sqlclient.insert_item item.merge(:feed => f[:meta][:link], :feed_title => f[:meta][:title])
      end
    end

    def repair(feed_url)
      unless feed_url =~ /^http:\/\//
        feed_url = "http://" + feed_url
      end
      feed_url.strip
    end

    def log(text)
      $stderr.puts text
    end
  end
end

if __FILE__ == $0
  Vnews::Feed.new(ARGV.first, ARGV.last).fetch
end

