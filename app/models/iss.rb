require 'net/http'
require 'uri'

module ISS

  PREFIX = "http://beta.micex.ru/iss"
  
  class << self
  
    def filters(engine, market)
      Rails.cache.fetch([:filters, engine, market].join('/'), :expires_in => 5.minutes) do
        url = URI.parse("#{PREFIX}/engines/#{engine}/markets/#{market}/securities/columns/filters.json?iss.meta=off&iss.only=filters")
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.get([url.path, url.query].join('?'))
        end
        prepare_filters(ActiveSupport::JSON.decode(res.body))
      end
    end
  
    def columns(engine, market)
      Rails.cache.fetch([:columns, engine, market].join('/'), :expires_in => 5.minutes) do
        url = URI.parse("#{PREFIX}/engines/#{engine}/markets/#{market}/securities/columns.json?iss.meta=off&iss.only=securities,marketdata")
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.get([url.path, url.query].join('?'))
        end
        prepare_columns(ActiveSupport::JSON.decode(res.body))
      end
    end
    
  private
  
    def iss_merge(columns, data)
      data.inject([]) do |memo, record|
        result = record.each_with_index.inject({}) do |memo, (field, index)|
          memo[columns[index]] = field
          memo
        end
        memo.push result
      end
    end

    def prepare_filters(filters)
      iss_merge(filters['filters']['columns'], filters['filters']['data']).inject({}) do |memo, record|
        (memo[record['filter_name'].to_sym] ||= []).push({ 'id' => record['id'], 'name' => record['name'] })
        memo
      end
    end
    
    def prepare_columns(columns)
      securities = iss_merge(columns['securities']['columns'], columns['securities']['data']).inject({}) { |memo, record| memo[record['id']] = record; memo }
      marketdata = iss_merge(columns['marketdata']['columns'], columns['marketdata']['data']).inject({}) { |memo, record| memo[record['id']] = record; memo }
      securities.merge(marketdata).values
    end
  
  end
  
end
