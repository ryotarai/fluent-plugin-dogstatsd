module Fluent
  class DogstatsdOutput < BufferedOutput
    Plugin.register_output('dogstatsd', self)

    config_param :host, :string, :default => nil
    config_param :port, :integer, :default => nil
    config_param :use_tag_as_key, :bool, :default => false

    unless method_defined?(:log)
      define_method(:log) { $log }
    end

    attr_accessor :statsd

    def initialize
      super

      require 'statsd' # dogstatsd-ruby
      require 'fluent/plugin/dogstatsd/statsd_patch'
    end

    def start
      super

      host = @host || Statsd::DEFAULT_HOST
      port = @port || Statsd::DEFAULT_PORT

      @statsd ||= Statsd.new(host, port)
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      @statsd.batch do |s|
        chunk.msgpack_each do |tag, time, record|
          key = if @use_tag_as_key
                  tag
                else
                  record['key']
                end

          value = record['value']

          options = {}

          case record['type']
          when 'increment'
            s.increment(key, options)
          when 'decrement'
            s.decrement(key, options)
          when 'count'
            s.count(key, value, options)
          when 'gauge'
            s.gauge(key, value, options)
          when 'histogram'
            s.histogram(key, value, options)
          when 'timing'
            s.timing(key, value, options)
          when 'set'
            s.set(key, value, options)
          when 'event'
            s.event(record['title'], record['text'], options)
          end
        end
      end
    end
  end
end

