require 'natalie/inline'
require 'ffi.cpp'

__ld_flags__ '-lffi -ldl'

module FFI
  class NotFoundError < LoadError
  end

  class Enum
    attr_reader :symbol_map

    def initialize(values)
      @symbol_map = {}
      i = 0
      while i < values.size
        name = values[i]
        raise TypeError, "expected Symbol, got #{enum_name.class}" unless name.is_a?(Symbol)
        i += 1
        value =
          if values[i].is_a?(Integer)
            i += 1
            values[i - 1]
          elsif !@symbol_map.empty?
            @symbol_map.values.last + 1
          else
            0
          end
        @symbol_map[name] = value
      end
      @symbol_map.freeze
    end

    alias to_h symbol_map
    alias to_hash symbol_map

    def symbols
      @symbol_map.keys
    end

    # NATFIXME: What is this second argument?
    def from_native(native, _)
      @symbol_map.invert.fetch(native, native)
    end

    # NATFIXME: What is this second argument?
    def to_native(symbol, _)
      @symbol_map.fetch(symbol) do
        raise ArgumentError, "invalid enum value, #{symbol.inspect}" unless symbol.is_a?(Integer)
        symbol
      end
    end
  end

  module Library
    __bind_method__ :ffi_lib, :FFI_Library_ffi_lib
    __bind_method__ :attach_function, :FFI_Library_attach_function

    def callback(name, param_types, return_type)
      @ffi_typedefs ||= {}
      @ffi_typedefs[name] = FFI::FunctionType.new(param_types, return_type)
    end

    def enum(*args)
      if args.size == 2 && args[0].is_a?(Symbol) && args[1].is_a?(Array)
        name, values = args
        @ffi_enums ||= {}
        @ffi_enums[name] = FFI::Enum.new(values)
      else
        FFI::Enum.new(args)
      end
    end
  end

  class FunctionType
    def initialize(param_types, return_type)
      @param_types = param_types
      @return_type = return_type
    end

    attr_reader :param_types, :return_type
  end

  class DynamicLibrary
    def initialize(name, lib)
      @name = name
      @lib = lib
    end

    attr_reader :name
  end

  class AbstractMemory
    __bind_method__ :put_int8, :FFI_AbstractMemory_put_int8
    alias put_char put_int8
  end

  class Pointer < AbstractMemory
    __bind_method__ :address, :FFI_Pointer_address
    __bind_method__ :autorelease?, :FFI_Pointer_is_autorelease
    __bind_method__ :autorelease=, :FFI_Pointer_set_autorelease
    __bind_method__ :free, :FFI_Pointer_free
    __bind_method__ :initialize, :FFI_Pointer_initialize
    __bind_method__ :read_string, :FFI_Pointer_read_string
    __bind_method__ :to_obj, :FFI_Pointer_to_obj
    __bind_method__ :write_string, :FFI_Pointer_write_string

    def self.from_env
      __inline__ <<~END
        auto e = env->caller();
        return self.send(env, "new"_s, { Value::integer((uintptr_t)e) });
      END
    end

    def self.new_env
      __inline__ <<~END
        auto e = Env::create(env->caller());
        return self.send(env, "new"_s, { Value::integer((uintptr_t)e) });
      END
    end

    def self.new_value
      __inline__ <<~END
        auto *v = new Value;
        return self.send(env, "new"_s, { Value::integer((uintptr_t)v) });
      END
    end

    attr_reader :type_size

    def null?
      address == 0
    end

    def ==(other)
      case other
      when nil
        null?
      when Pointer
        address == other.address
      else
        false
      end
    end
  end

  class MemoryPointer < Pointer
    __bind_method__ :initialize, :FFI_MemoryPointer_initialize
    __bind_method__ :inspect, :FFI_MemoryPointer_inspect
  end
end

class Object
  __bind_method__ :to_ptr, :Object_to_ptr
end
