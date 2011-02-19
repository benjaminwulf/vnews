require 'mysql2'
class Vnews
  class Sql
    def initialize(config = {})
      defaults = {:host => 'localhost', :username => 'root', :database => 'vnews'}
      @config = defaults.update(config)
      @client = Mysql2::Client.new @config
    end

    def insert_feed(title, feed_url, link, folder=nil)
      if folder.nil?
        folder = 'Main'
      end
      @client.query "INSERT IGNORE INTO feeds (title, feed_url, link) VALUES ('#{e title}', '#{e feed_url}', '#{e link}')"
      if folder
        @client.query "INSERT IGNORE INTO feeds_folders (feed, folder) VALUES ('#{e feed_url}', '#{e folder}')"
      end
    end

    def insert_item(item)
      # not sure if this is efficient
      @client.query "DELETE from items WHERE guid = '#{e item[:guid]}' and feed = '#{e item[:feed_title]}'"
      @client.query "INSERT IGNORE INTO items (guid, feed, feed_title, title, link, pub_date, author, text, word_count) 
        VALUES (
        '#{e item[:guid]}', 
        '#{e item[:feed]}', 
        '#{e item[:feed_title]}', 
        '#{e item[:title]}', 
        '#{e item[:link]}', 
        '#{item[:pub_date]}',  
        '#{e item[:author]}',  
        '#{e item[:content][:text]}',
        '#{item[:content][:text].scan(/\S+/).size}'
        )"
    end

    # queries:

    def folders
      @client.query("SELECT folder, count(*) as count from feeds_folders group by folder order by folder")
    end

    def feeds(folder)
      condition = folder.nil? ? "ff.folder = 'main'" : "ff.folder = '#{e folder}'"
      @client.query("SELECT feeds.* from feeds left join feeds_folders ff on (ff.feed = feeds.link) where #{condition} order by feeds.title") 
    end

    def feed_items(feed) # feed is xml URL
      if feed
        @client.query("SELECT items.title, guid, feed, feed_title, pub_date, word_count from items where items.feed = '#{e feed}' order by pub_date desc") 
      else
        @client.query("SELECT items.title, guid, feed, feed_title, pub_date, word_count from items order by pub_date desc") 
      end
    end

    def folder_items(folder) 
      query = "SELECT items.title, items.guid, items.feed, items.feed_title, items.pub_date, items.word_count from items 
                    inner join feeds_folders ff on  ff.feed = items.feed
                    where ff.folder = '#{e folder}' order by pub_date desc"
      puts query
      @client.query query
    end


    # escape
    def e(value)
      return unless value
      @client.escape(value)
    end
  end

  SQLCLIENT = Sql.new() # TODO inject config here
end
