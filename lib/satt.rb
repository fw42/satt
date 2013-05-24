require "msgpack"

class Satt
  class InvalidArgument < RuntimeError; end

  def self.dump(obj)
    MessagePack.dump(Satt::Primitive::Dumper.new.dump(obj))
  end

  def self.load(blob)
    Satt::Primitive::Loader.new.load(MessagePack.load(blob))
  end
end

class Satt
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
        when String
          obj
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
        raise InvalidArgument, priv.inspect if priv.class != Array or priv.empty?
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

        if priv.length == 2
          return build_and_cache_obj(objclass, priv[1])
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

        if objclass == String
          raise InvalidArgument if priv.last.class != String
          return cache_obj(priv[1], priv[2])
        end

        if priv.last.class != Hash
          raise InvalidArgument, priv.last.inspect
        end

        return build_and_cache_obj(objclass, priv[1], priv[2])
      end

      private

      def cache_has(ref)
        @objs.key?(ref)
      end

      def cache_obj(ref, obj=nil)
        @objs[ref] ||= obj
      end

      def build_and_cache_obj(objclass, ref, ivars=[])
        # Cache first, only then go deeper, to avoid following circular references
        obj = cache_obj(ref, cache_has(ref) ? nil : objclass.allocate)
        ivars.each do |(var, val)|
          obj.instance_variable_set "@#{var}".to_sym, load(val)
        end
        return obj
      end

      def get_class(id)
        return OTHER_PRIMITIVES[id] if id.class == Fixnum
        unless Object.constants.include?(id.to_sym) and objclass = Object.const_get(id) and objclass.class == Class
          raise InvalidArgument, "unknown class #{id.to_s}"
        end
        objclass
      end
    end
  end
end
