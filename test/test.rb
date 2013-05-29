require 'minitest/unit'
require 'minitest/autorun'
require File.expand_path("../../lib/satt.rb", __FILE__)
require File.expand_path("../examples.rb", __FILE__)

class Foo
  attr_accessor :x
end

class Bla
end

module A
  class B
  end
end

class C
  class D
  end
end

module CustomMarshalA
  attr_accessor :x, :y

  def self.included(base)
    base.extend ClassMethods
  end

  def marshal_dump
    { x: 42, y: 23 }
  end

  module ClassMethods
    def marshal_load(h)
      x = new
      x.x = h[:x]
      x.y = h[:y]
      return x
    end
  end
end

module CustomMarshalB
  attr_accessor :x

  def self.included(base)
    base.extend ClassMethods
  end

  def _dump
    1337
  end

  module ClassMethods
    def _load(str)
      x = new
      x.x = str.to_i
      return x
    end
  end
end

class CustomA
  include CustomMarshalA
end

class CustomB
  include CustomMarshalB
end

class CustomC
  include CustomMarshalA
  include CustomMarshalB
end

class SattTest < MiniTest::Unit::TestCase
  def roundtrip(obj)
    Satt.load(Satt.dump(obj))
  end

  def test_strings_hashes_and_arrays_are_stored_by_reference
    objs = [ "foo", [ 1, 2, 3 ], { foo: 42 }]
    objs.each do |obj|
      x = [ obj, obj ]
      y = roundtrip(x)
      assert_equal y[0].__id__, y[1].__id__
    end
  end

  def test_dump_returns_a_valid_msgpack_string
    y = Satt.dump("foo")
    assert_equal String, y.class
    MessagePack.unpack(y)
  end

  def test_loading_garbage_raises_exception
    garbage = MessagePack.pack("123foobar")
    assert_raises Satt::InvalidArgument do
      Satt.load(garbage)
    end
  end

  def test_some_primitive_examples
    EXAMPLES.each do |ex|
      assert_equal ex, roundtrip(ex)
    end
  end

  def test_some_simple_objects_with_ivars
    foo = Foo.new
    foo.x = 42
    assert_equal 42, roundtrip(foo).x
  end

  def test_self_referencing_hashes
    x = {}
    x[x] = x
    y = roundtrip(x)
    assert_equal y.class, Hash
    assert_equal y.__id__, y.keys.first.__id__
  end

  def test_self_referencing_arrays
    x = []
    x.push(x)
    y = roundtrip(x)
    assert_equal y.class, Array
    assert_equal y.__id__, y.first.__id__
  end

  def test_self_referencing_objects
    foo = Foo.new
    foo.x = foo
    y = roundtrip(foo)
    assert_equal y.class, Foo
    assert_equal y, y.x
    assert_equal y.__id__, y.x.__id__
  end

  def test_simple_ciruclar_references
    f1 = Foo.new
    f2 = Foo.new
    f3 = Foo.new
    f1.x = f2
    f2.x = f3
    f3.x = f1
    f1, f2, f3 = roundtrip([ f1, f2, f3 ])
    assert_equal f1.class, Foo
    assert_equal f2.class, Foo
    assert_equal f3.class, Foo
    assert_equal f1.x, f2
    assert_equal f2.x, f3
    assert_equal f3.x, f1
  end

  def test_loading_instance_of_unknown_class_raises_exception
    blob = Satt.dump(Bla.new)
    Object.send(:remove_const, :Bla)
    assert_raises Satt::InvalidArgument do
      Satt.load(blob)
    end
  end

  def test_nested_namespaces
    b = A::B.new
    d = C::D.new
    y = roundtrip([ b, d ])
    assert_equal A::B, y.first.class
    assert_equal C::D, y.last.class
  end

  def test_custom_marshal_dump_and_marshal_load
    x = CustomA.new
    x.x, x.y = 0, 0
    y = roundtrip(x)
    assert 42, y.x
    assert 23, y.y
  end

  def test_custom_dump_and_load
    x = CustomB.new
    x.x = 42
    y = roundtrip(x)
    assert 1337, y.x
  end

  def test_marshal_dump_and_marshal_load_have_higher_precedence_than_custom_load_and_dump
    x = CustomC.new
    x.x = 0
    y = roundtrip(x)
    assert 42, y.x
  end
end
