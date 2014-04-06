require 'cinch'
require 'simple-rss'
require 'open-uri'
require 'date'

module Chelsea::RSS
  class RSSPlugin
    include Cinch::Plugin

    def initialize(bot)
      super(bot)
      @channels = config['channels']
      @data_dir = config['data_dir']
      @rss_list = config['rss_list']
      @rss_plugin_data_file = "#{@data_dir}/rss_plugin_data.yml"
      
      create_data_dir
      load_state
    end

    timer 60, method: :execute

    def load_state
      if File.exist?(@rss_plugin_data_file)
        @rss_plugin_data = YAML.load_file(@rss_plugin_data_file)
      else
        @rss_plugin_data = {"rss_list" => []}
      end

      @rss_list.each { |i|
        unless @rss_plugin_data['rss_list'].find { |j| i['name'] == j['name'] }
          @rss_plugin_data['rss_list'].push({
             'name' => i['name'],
             'url' => i['url'],
             'last_modified' => DateTime.parse(Time.at(0).to_s)
          })
        end
      }
    end

    def save_state
      File.open(@rss_plugin_data_file, 'w') { |f| f.write(@rss_plugin_data.to_yaml) }
    end

    def create_data_dir
      unless Dir.exist?(@data_dir)
        Dir.mkdir(@data_dir)
      end
    end

    def execute
      updated = update_all
    end

    def update_all
      @rss_plugin_data['rss_list'].map { |rss_info|
        begin 
          update_then_notify(rss_info)
        rescue => e
          broadcast("error occurred while updating #{rss_info['name']}")
          debug e.inspect
          debug e.backtrace
          rss_info
        end
      }

      save_state
    end

    def broadcast(msg)
      @channels.each { |c| Channel(c).send(msg) }
    end

    def update_then_notify(rss_info)
      rss_parsed = SimpleRSS.parse(open(rss_info['url']))

      new_articles = rss_parsed.items.select { |item|
        rss_info['last_modified'] < DateTime.parse(item.pubDate.to_s)
      }
      
      unless new_articles.empty? then
        rss_info['last_modified'] = DateTime.parse(new_articles.first.pubDate.to_s)
        header = "[#{rss_info['name']}]"
        new_articles.each { |article|
          broadcast("#{header} - #{article.title} / #{article.link}")
        }
      end

      rss_info
    end

  end
end
