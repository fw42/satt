class Sattr
  class InvalidArgument < RuntimeError; end

  def initialize(serializer=nil)
    @serializer = serializer || MessagePack
  end

  def dump(obj)
    dumper = Sattr::Primitive::Dumper.new()
    @serializer.dump(dumper.dump(obj))
  end

  def load(blob)
    loader = Sattr::Primitive::Loader.new()
    loader.load(@serializer.load(blob))
  end
end

class Sattr
  class Primitive
    NOT_DUMPABLE     = [ Binding, IO, Proc, Class ].freeze
    DONT_SERIALIZE   = [ NilClass, Fixnum, Float, TrueClass, FalseClass ].freeze
    OTHER_PRIMITIVES = [ Symbol, String, Array, Hash, Bignum ].freeze

    class Dumper
      def initialize()
        @next_id = 0
        @ids = {}
      end

      def dump(obj)
        NOT_DUMPABLE.each do |cl|
          raise InvalidArgument, "objects of type #{cl.to_s} are not dumpable" if obj.is_a?(cl)
        end

        case obj
        when *DONT_SERIALIZE
          obj
        when Symbol, Bignum
          [ class_identifier(obj), dump_value(obj) ]
        else
          id, cached = local_id(obj)
          arr = [ class_identifier(obj), id ]
          arr << dump_value(obj) unless cached
          arr
        end
      end

      private

      def dump_value(obj)
        case obj
        when Symbol
          obj.to_s
        when Bignum
          obj.to_s(16)
        when Array
          obj.map{ |e| dump(e) }
        when Hash
          obj.reduce(Hash.new) do |hash, (key, value)|
            hash[dump(key)] = dump(value)
            hash
          end
        else
          obj.instance_variables.inject(Hash.new) do |hash, (var, val)|
            hash[var.to_s[1..-1]] = dump(obj.instance_variable_get(var))
            hash
          end
        end
      end

      def local_id(obj)
        if @ids.key?(obj.__id__)
          [ @ids[obj.__id__], true ]
        else
          [ @ids[obj.__id__] = (@next_id += 1), false ]
        end
      end

      def class_identifier(obj)
        if idx = OTHER_PRIMITIVES.index(obj.class)
          idx
        else
          obj.class.to_s
        end
      end
    end

    class Loader
      def initialize()
        @objs = {}
      end

      def load(priv)
        return priv if DONT_SERIALIZE.include?(priv.class)
        raise InvalidArgument if priv.class != Array or priv.empty?
        objclass = get_class(priv.first)

        if objclass == Symbol
          raise InvalidArgument unless priv.length == 2 and priv.last.class == String
          return priv.last.to_sym
        end

        if objclass == Bignum
          raise InvalidArgument unless priv.length == 2 and priv.last.class == String
          return priv.last.to_i(16)
        end

        if [Array, Hash].include?(objclass) and priv.length == 3
          raise InvalidArgument unless priv.last.class == objclass
        end

        # TODO: allocate object immediatelly and add to cache
        # even if ivars not present (but come later), error if two entries
        # with same id and both with ivars
        if priv.length == 2
          return fetch_obj(priv[1])
        end

        if objclass == Array
          return cache_obj(priv[1], priv[2].map{ |e| load(e) })
        end

        if objclass == Hash
          return cache_obj(priv[1], priv[2].reduce(Hash.new) { |hash, (key, value)|
            hash[load(key)] = load(value)
            hash
          })
        end

        if priv.last.class != Hash
          raise InvalidArgument
        end

        return build_and_cache_obj(objclass, priv[1], priv[2])
      end

      private

      def fetch_obj(ref)
        return @objs[ref] if @objs[ref]
        raise InvalidArgument, "can't find object with reference id #{ref.to_s}"
      end

      def cache_obj(ref, obj)
        return @objs[ref] = obj unless @objs[ref]
        raise InvalidArgument, "an object with reference id #{ref.to_s} already exists"
      end

      def build_and_cache_obj(objclass, ref, ivars)
        # Cache first, only then go deeper, to avoid following circular references
        obj = cache_obj(ref, objclass.allocate)
        ivars.each do |(var, val)|
          obj.instance_variable_set "@#{var}".to_sym, load(val)
        end
        return obj
      end

      def get_class(id)
        return OTHER_PRIMITIVES[id] if OTHER_PRIMITIVES[id]
        unless Object.constants.include?(id.to_sym) and objclass = Object.const_get(id) and objclass.class == Class
          raise InvalidArgument, "unknown class #{id.to_s}"
        end
        objclass
      end
    end
  end
end

begin
  require "msgpack"
rescue LoadError
end

class Foo
  attr_accessor :x
end

f1 = Foo.new
f2 = Foo.new
f1.x = f2
f2.x = f1

require "pry"
binding.pry
