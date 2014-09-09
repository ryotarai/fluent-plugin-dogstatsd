require 'statsd'

# https://github.com/DataDog/dogstatsd-ruby/pull/10
class Statsd
  def flush_buffer()
    send_to_socket(@buffer.join("\n"))
    @buffer = Array.new
  end
end
