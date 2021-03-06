unless defined?(MessagePack)
  require "msgpack"
end

unless defined?(BigDecimal)
  class BigDecimal
  end
end

class Satt
  class InvalidArgument < RuntimeError; end

  def self.dump(obj)
    MessagePack.pack(Satt::Primitive::Dumper.new.dump(obj))
  end

  def self.load(blob)
    Satt::Primitive::Loader.new.load(MessagePack.unpack(blob))
  end
end

class Satt
  class Primitive
    NOT_DUMPABLE     = [ Binding, IO, Proc, Class ].freeze
    DONT_SERIALIZE   = [ NilClass, Fixnum, Float, TrueClass, FalseClass ].freeze
    OTHER_PRIMITIVES = [ Symbol, String, Array, Hash, Bignum, BigDecimal ].freeze

    class Dumper
      def initialize()
        @next_id = 0
        @ids = {}
      end

      def dump(obj)
        NOT_DUMPABLE.each do |cl|
          raise InvalidArgument, "objects of type #{cl.to_s} are not dumpable" if obj.is_a?(cl)
        end

        if obj.respond_to?(:marshal_dump)
          return [ class_identifier(obj), dump(obj.marshal_dump) ]
        end

        if obj.respond_to?(:_dump)
          return [ class_identifier(obj), obj._dump ]
        end

        case obj
        when *DONT_SERIALIZE
          obj
        when Symbol, Bignum, BigDecimal
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
        when String
          obj
        when Symbol
          obj.to_s
        when Bignum, BigDecimal
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
        raise InvalidArgument, priv.inspect if priv.class != Array or priv.empty?
        objclass = get_class(priv.first)

        if objclass.respond_to?(:marshal_load)
          raise InvalidArgument unless priv.length == 2
          return objclass.marshal_load(load(priv.last))
        end

        if objclass.respond_to?(:_load)
          raise InvalidArgument, priv.inspect unless priv.length == 2
          return objclass._load(priv.last)
        end

        if objclass == Symbol
          raise InvalidArgument unless priv.length == 2 and priv.last.class == String
          return priv.last.to_sym
        end

        if objclass == Bignum
          raise InvalidArgument unless priv.length == 2 and priv.last.class == String
          return priv.last.to_i(16)
        end

        if objclass == BigDecimal
          raise InvalidArgument unless priv.length == 2 and priv.last.class == String
          return BigDecimal.new(priv.last)
        end

        if [Array, Hash].include?(objclass) and priv.length == 3
          raise InvalidArgument unless priv.last.class == objclass
        end

        if priv.length == 2 and cache_has(priv[1])
          return cache_get(priv[1])
        end

        obj = cache_has(priv[1]) ? cache_get(priv[1]) : cache_put(priv[1], objclass.allocate)

        if objclass == Array
          priv[2].each_with_index do |e,i|
            obj[i] = load(e)
          end
          return obj
        end

        if objclass == Hash
          return priv[2].reduce(obj) { |hash, (key, value)|
            hash[load(key)] = load(value)
            hash
          }
        end

        if objclass == String
          raise InvalidArgument if priv.last.class != String
          return obj.gsub!(/\A.*\z/, priv[2])
        end

        if priv.last.class != Hash
          raise InvalidArgument, priv.last.inspect
        end

        priv[2].each do |(var, val)|
          obj.instance_variable_set "@#{var}".to_sym, load(val)
        end
        return obj
      end

      private

      def cache_has(ref)
        @objs.key?(ref)
      end

      def cache_get(ref)
        @objs[ref]
      end

      def cache_put(ref, obj)
        @objs[ref] = obj
      end

      def get_class(id)
        return OTHER_PRIMITIVES[id] if id.class == Fixnum
        path = id.split("::")
        objclass = Object
        while tmp = path.shift
          unless objclass.constants.include?(tmp.to_sym) and
            objclass = objclass.const_get(tmp) and
            (objclass.class == Class or (path != [] and objclass.class == Module)) then
            raise InvalidArgument, "unknown class #{id.to_s}"
          end
          objclass
        end
        objclass
      end
    end
  end
end
