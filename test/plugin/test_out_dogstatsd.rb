require 'test_helper'

class DummyStatsd
  attr_reader :messages

  def initialize
    @messages = []
  end

  def batch
    yield(self)
  end

  %i!increment decrement count gauge histogram timing set event!.each do |name|
    define_method(name) do |*args|
      @messages << [name, args].flatten
    end
  end
end

class DogstatsdOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    require 'fluent/plugin/out_dogstatsd'
  end

  def teardown
  end

  def test_configure
    d = create_driver(<<-EOC)
      type dogstatsd
      host HOST
      port 12345
    EOC

    assert_equal('HOST', d.instance.host)
    assert_equal(12345, d.instance.port)
  end

  def test_write
    d = create_driver

    d.instance.statsd = DummyStatsd.new

    d.emit({'type' => 'increment', 'key' => 'hello.world1'}, Time.now.to_i)
    d.emit({'type' => 'increment', 'key' => 'hello.world2'}, Time.now.to_i)
    d.emit({'type' => 'decrement', 'key' => 'hello.world'}, Time.now.to_i)
    d.emit({'type' => 'count', 'value' => 10, 'key' => 'hello.world'}, Time.now.to_i)
    d.emit({'type' => 'gauge', 'value' => 10, 'key' => 'hello.world'}, Time.now.to_i)
    d.emit({'type' => 'histogram', 'value' => 10, 'key' => 'hello.world'}, Time.now.to_i)
    d.emit({'type' => 'timing', 'value' => 10, 'key' => 'hello.world'}, Time.now.to_i)
    d.emit({'type' => 'set', 'value' => 10, 'key' => 'hello.world'}, Time.now.to_i)
    d.emit({'type' => 'event', 'title' => 'Deploy', 'text' => 'Revision', 'key' => 'hello.world'}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:increment, 'hello.world1', {}],
      [:increment, 'hello.world2', {}],
      [:decrement, 'hello.world', {}],
      [:count, 'hello.world', 10, {}],
      [:gauge, 'hello.world', 10, {}],
      [:histogram, 'hello.world', 10, {}],
      [:timing, 'hello.world', 10, {}],
      [:set, 'hello.world', 10, {}],
      [:event, 'Deploy', 'Revision', {}],
    ])
  end

  private
  def default_config
    <<-EOC
    type dogstatsd
    EOC
  end

  def create_driver(conf = default_config)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::DogstatsdOutput, 'dogstatsd.tag').configure(conf)
  end
end

