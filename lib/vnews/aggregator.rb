require 'rexml/document'
require 'nokogiri'
require 'open-uri'
require 'feedzirra'
require 'logger'
require 'yaml'

class Vnews
  class Aggregator
    def initialize(config={})
      @logger = Logger.new(config[:logfile] || STDERR)
    end

    def get_feed(feed_url)
      feed_url = repair feed_url
      feed = Feedzirra::Feed.fetch_and_parse feed_url
      if feed.nil?
        log "Can't find feed at #{feed_url}\nAttempting autodiscovery"
        feed_url = auto_discover(feed_url)
        if feed_url
          puts "Subscribing to #{feed_url}"
          feed = Feedzirra::Feed.fetch_and_parse feed_url
        else
          raise SubscribeFailed
        end
      end
      feed_to_hash(feed_url, feed)
    end

    def feed_to_hash(feed_url, feed)
      #feed.sanitze_entries! 
      { 
        :title => feed.title,
        # It's very importannt that this is feed_url and not feed.url:
        :feed_url => feed.url, 
        :original_feed_url => feed_url,
        :etag => feed.etag, 
        :last_modified => feed.last_modified,
        :entries => feed.entries.map {|entry|
          {:title => entry.title.sanitize,
            :url => entry.url,
            :author => entry.author,
            :summary => entry.summary,
            :content => entry.content,
            :published => entry.published,
            :categories => entry.categories }}
      }
    end

    def auto_discover(feed_url)
      doc = Nokogiri::HTML.parse(fetch(feed_url))
      feed_url = [ 'head link[@type=application/atom+xml]', 
        'head link[@type=application/rss+xml]', 
        "head link[@type=text/xml]"].detect do |path|
          doc.at(path)
        end
      if feed_url
        feed_url
      else
        raise AutodiscoveryFailed, "can't discover feed url at #{url}"
      end
    end

    def import_opml(opml)
      doc = REXML::Document.new(opml) 
      feed_urls = doc.elements.map('//outline[@xmlUrl]') do |e|
        e.attributes['xmlUrl']
      end.uniq.each do |url|
        subscribe(url)
      end
    end
   
    def repair(feed_url)
      unless feed_url =~ /^http:\/\//
        feed_url = "http://" + feed_url
      end
      feed_url
    end

    def log(text)
      @logger.debug text
    end

    def self.start_drb_server(config)
      outline = self.new(config)
      use_uri = config['drb_uri'] || nil # redundant but explicit
      DRb.start_service(use_uri, outline)
      DRb.uri
    end
  end
end

if __FILE__ == $0
  vnews = Vnews::Aggregator.new
  res = vnews.get_feed ARGV.first
  puts res.to_yaml
end

