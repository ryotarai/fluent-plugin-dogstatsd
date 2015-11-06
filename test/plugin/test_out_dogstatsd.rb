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

  def test_flat_tag
    d = create_driver(<<-EOC)
#{default_config}
flat_tag true
    EOC

    d.emit({'type' => 'increment', 'key' => 'hello.world', 'tagKey' => 'tagValue'}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:increment, 'hello.world', {tags: ["tagKey:tagValue"]}],
    ])
  end

  def test_metric_type
    d = create_driver(<<-EOC)
#{default_config}
metric_type decrement
    EOC

    d.emit({'key' => 'hello.world', 'tags' => {'tagKey' => 'tagValue'}}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:decrement, 'hello.world', {tags: ["tagKey:tagValue"]}],
    ])
  end

  def test_use_tag_as_key
    d = create_driver(<<-EOC)
#{default_config}
use_tag_as_key true
    EOC

    d.emit({'type' => 'increment'}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:increment, 'dogstatsd.tag', {}],
    ])
  end

  def test_use_tag_as_key_fallback
    d = create_driver(<<-EOC)
#{default_config}
use_tag_as_key_if_missing true
    EOC

    d.emit({'type' => 'increment'}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:increment, 'dogstatsd.tag', {}],
    ])
  end

  def test_tags
    d = create_driver
    d.emit({'type' => 'increment', 'key' => 'hello.world', 'tags' => {'key' => 'value'}}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:increment, 'hello.world', {tags: ["key:value"]}],
    ])
  end

  def test_sample_rate_config
    d = create_driver(<<-EOC)
#{default_config}
sample_rate .5
    EOC

    d.emit({'type' => 'increment', 'key' => 'tag'}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:increment, 'tag', {sample_rate: 0.5}],
    ])
  end

  def test_sample_rate
    d = create_driver
    d.emit({'type' => 'increment', 'sample_rate' => 0.5, 'key' => 'tag'}, Time.now.to_i)
    d.run

    assert_equal(d.instance.statsd.messages, [
      [:increment, 'tag', {sample_rate: 0.5}],
    ])
  end

  private
  def default_config
    <<-EOC
    type dogstatsd
    EOC
  end

  def create_driver(conf = default_config)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::DogstatsdOutput, 'dogstatsd.tag').configure(conf).tap do |d|
      d.instance.statsd = DummyStatsd.new
    end
  end
end

