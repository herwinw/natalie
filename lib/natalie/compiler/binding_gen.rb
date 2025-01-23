class BindingGen
  def initialize
    @bindings = {}
    @undefine_methods = []
    @undefine_singleton_methods = []
  end

  # define a method on the Ruby class and link it to a method on the C++ class
  def binding(*args, **kwargs)
    b = Binding.new(*args, **kwargs)
    b.increment_name while @bindings[b.name]
    @bindings[b.name] = b
    b.write
  end

  # define a method on the Ruby *SINGLETON* class and link it to a member function on the C++ class
  def member_binding_as_class_method(*args, **kwargs)
    binding(*args, **{
      ruby_method_type: :class
    }.update(kwargs))
  end

  # define a method on the Ruby *SINGLETON* class and link it to a *STATIC* function on the C++ class
  def static_binding_as_class_method(*args, **kwargs)
    binding(*args, **{
      cpp_function_type: :static,
      ruby_method_type: :class
    }.update(kwargs))
  end

  # define a method on the Ruby class and link it to a *STATIC* function on the C++ class
  def static_binding_as_instance_method(*args, **kwargs)
    binding(*args, **{
      cpp_function_type: :static,
      ruby_method_type: :instance,
      pass_self: true
    }.update(kwargs))
  end

  # define a private method on the Ruby class and a public method on the Ruby *SINGLETON* class
  def module_function_binding(*args, **kwargs)
    binding(*args, **{
      module_function: true,
      cpp_function_type: :static,
      ruby_method_type: :class,
      visibility: :private
    }.update(kwargs))
  end

  # mark a method as undefined on the Ruby class
  def undefine_instance_method(rb_class, method)
    @undefine_methods << [rb_class, method]
  end

  # mark a method as undefined on the Ruby singleton class
  def undefine_singleton_method(rb_class, method)
    @undefine_singleton_methods << [rb_class, method]
  end

  def init
    puts 'void init_bindings(Env *env) {'
    @consts = {}
    @bindings.values.each do |binding|
      unless @consts[binding.rb_class]
        puts '    ' + binding.get_object
        @consts[binding.rb_class] = true
      end
      puts "    #{binding.rb_class_as_c_variable}->#{binding.define_method_name}(env, #{binding.rb_method.inspect}_s, #{binding.name}, #{binding.arity}, #{binding.optimized ? 'true' : 'false'});"
      if binding.module_function?
        puts "    #{binding.rb_class_as_c_variable}->module_function(env, #{binding.rb_method.inspect}_s);"
      end
      if binding.needs_to_set_visibility?
        puts "    #{binding.rb_class_as_c_variable}->#{binding.set_visibility_method_name}(env, #{binding.rb_method.inspect}_s);"
      end
      binding.aliases.each do |method|
        puts "    #{binding.rb_class_as_c_variable}->#{binding.alias_name}(env, #{method.inspect}_s, #{binding.rb_method.inspect}_s);"
      end
    end
    @undefine_methods.each { |rb_class, method| puts "    #{rb_class}->undefine_method(env, #{method.inspect}_s);" }
    @undefine_singleton_methods.each do |rb_class, method|
      puts "    #{rb_class}->undefine_singleton_method(env, #{method.inspect}_s);"
    end
    puts '}'
  end

  class Binding
    def initialize(
      rb_class,
      rb_method,
      cpp_class,
      cpp_method,
      argc:,
      pass_env:,
      pass_block:,
      return_type:,
      cpp_function_type: :member,  # :static or :member
      ruby_method_type: :instance, # :class or :instance
      pass_self: false, # only relevant when cpp_function_type: :static
      cast_self: false, # only relevant when cpp_function_type: :static
      module_function: false,
      pass_klass: false,
      kwargs: nil,
      visibility: :public,
      optimized: false,
      aliases: []
    )
      @rb_class = rb_class
      @rb_method = rb_method
      @cpp_class = cpp_class
      @cpp_method = cpp_method
      @argc = argc
      @pass_env = pass_env
      @pass_block = pass_block
      @return_type = return_type
      @cpp_function_type = cpp_function_type
      @ruby_method_type = ruby_method_type
      @pass_self = pass_self
      @cast_self = cast_self
      @module_function = module_function
      @pass_klass = pass_klass
      @kwargs = kwargs
      @visibility = visibility
      @optimized = optimized
      @aliases = aliases
      generate_name
    end

    attr_reader :rb_class,
                :rb_method,
                :cpp_class,
                :cpp_method,
                :argc,
                :return_type,
                :cpp_function_type,
                :ruby_method_type,
                :name,
                :visibility,
                :optimized,
                :aliases

    def pass_env? = !!@pass_env
    def pass_self? = !!@pass_self
    def cast_self? = !!@cast_self
    def pass_klass? = !!@pass_klass
    def pass_block? = !!@pass_block
    def module_function? = !!@module_function

    def arity
      case argc
      when :any
        -1
      when Range
        (argc.begin * -1) - 1
      when Integer
        argc
      else
        raise "unknown argc: #{argc}"
      end
    end

    def method_accepts_integer_as_self?
      cpp_class == 'IntegerObject' && ruby_method_type == :instance
    end

    def write
      if cpp_function_type == :static
        lines = []
        if method_accepts_integer_as_self?
          lines << 'auto integer = self.integer();'
        end
        lines << "auto return_value = #{cpp_class}::#{cpp_method}(#{args_to_pass});"
        call = lines.join("\n")
      else
        call = "auto return_value = static_cast<#{cpp_class}*>(self.object())->#{cpp_method}(#{args_to_pass});"
      end

      body = <<~FUNC
        #{pop_kwargs}
        #{argc_assertion}
        #{kwargs_assertion}
        #{call}
        #{return_code}
      FUNC
      format_function_body(body)

      puts "Value #{name}(Env *env, Value self, Args &&args, Block *block) {\n#{body}\n}\n\n"
    end

    def format_function_body(body)
      # Delete empty lines
      body.chomp!
      body.gsub!(/^\n/, '')

      # Add indentation
      body.gsub!(/^/, ' ' * 4)
    end

    def args_to_pass
      case @kwargs
      when Array
        kwargs = @kwargs.map { |kw| "kwarg_#{kw}" }
      when true
        kwargs = 'kwargs'
      end

      if pass_self?
        if cast_self?
          if method_accepts_integer_as_self?
            self_arg = 'integer'
          else
            self_arg = "static_cast<#{cpp_class}*>(self.object())"
          end
        else
          self_arg = 'self'
        end
      end

      [
        pass_env? ? 'env' : nil,
        self_arg,
        *args,
        *kwargs,
        pass_block? ? 'block' : nil,
        pass_klass? ? 'self->as_class()' : nil,
      ].compact.join(', ')
    end

    def define_method_name
      if module_function?
        'define_method'
      elsif ruby_method_type == :class
        'define_singleton_method'
      else
        'define_method'
      end
    end

    def alias_name
      if module_function?
        'method_alias'
      elsif ruby_method_type == :class
        'singleton_method_alias'
      else
        'method_alias'
      end
    end

    def increment_name
      @name = @name.sub(/_binding(\d*)$/) { "_binding#{$1.to_i + 1}" }
    end

    GLOBAL_ENV_ACCESSORS = %w[Array Binding Class Float Hash Integer Module Object Regexp String Symbol main_obj]

    def get_object
      if GLOBAL_ENV_ACCESSORS.include?(rb_class)
        "Value #{rb_class} = GlobalEnv::the()->#{rb_class}();"
      else
        "Value #{rb_class_as_c_variable} = GlobalEnv::the()->Object()->#{rb_class.split('::').map { |c| "const_find(env, #{c.inspect}_s)" }.join('->')};"
      end
    end

    def rb_class_as_c_variable
      rb_class.gsub('::', '')
    end

    def needs_to_set_visibility?
      module_function? ? visibility != :private : visibility != :public
    end

    def set_visibility_method_name
      case visibility
      when :private
        'private_method'
      when :protected
        'protected_method'
      else
        raise "Unknown visibility: #{visibility.inspect}"
      end
    end

    private

    def pop_kwargs
      case @kwargs
      when Array
        "auto kwargs = args.pop_keyword_hash();\n" +
          @kwargs.map { |kw| "auto kwarg_#{kw} = kwargs ? kwargs->remove(env, #{kw.to_s.inspect}_s) : nullptr;" }.join("\n")
      when true
        "auto kwargs = args.pop_keyword_hash();\n"
      end
    end

    def argc_assertion
      case argc
      when :any
        ''
      when Range
        if argc.end
          "args.ensure_argc_between(env, #{argc.begin}, #{argc.end});"
        else
          "args.ensure_argc_at_least(env, #{argc.begin});"
        end
      when Integer
        "args.ensure_argc_is(env, #{argc});"
      else
        raise "Unknown argc: #{argc.inspect}"
      end
    end

    def kwargs_assertion
      'env->ensure_no_extra_keywords(kwargs);' if @kwargs.is_a?(Array)
    end

    def args
      if max_argc
        (0...max_argc).map { |i| "args.at(#{i}, nullptr)" }
      else
        ['std::move(args)']
      end
    end

    def return_code
      case return_type
      when :bool
        'return bool_object(return_value);'
      when :int
        'return Value::integer(return_value);'
      when :size_t
        'return IntegerObject::from_size_t(env, return_value);'
      when :Object
        "if (!return_value) return NilObject::the();\nreturn return_value;"
      else
        raise "Unknown return type: #{return_type.inspect}"
      end
    end

    def max_argc
      case argc
      when :any
        nil
      when Range
        argc.end
      when Integer
        argc
      end
    end

    def generate_name
      @name = "#{rb_class_as_c_variable}_#{cpp_method}"
      if @module_function
        @name << '_module_function'
      else
        @name << '_static' if cpp_function_type == :static
        @name << "_#{@visibility}"
      end
      @name << '_binding'
    end
  end
end

puts '// DO NOT EDIT THIS FILE BY HAND!'
puts '// This file is generated by the lib/natalie/compiler/binding_gen.rb script.'
puts
puts '#include "natalie.hpp"'
puts
puts 'namespace Natalie {'
puts

gen = BindingGen.new

gen.static_binding_as_class_method('Array', '[]', 'ArrayObject', 'square_new', argc: :any, pass_env: true, pass_block: false, pass_klass: true, return_type: :Object)
gen.static_binding_as_class_method('Array', 'try_convert', 'ArrayObject', 'try_convert', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', '+', 'ArrayObject', 'add', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', '-', 'ArrayObject', 'sub', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', '*', 'ArrayObject', 'multiply', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', '&', 'ArrayObject', 'intersection', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', '<<', 'ArrayObject', 'ltlt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', '<=>', 'ArrayObject', 'cmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'eql?', 'ArrayObject', 'eql', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Array', '==', 'ArrayObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Array', '===', 'ArrayObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Array', '[]', 'ArrayObject', 'ref', argc: 1..2, pass_env: true, pass_block: false, aliases: ['slice'], return_type: :Object)
gen.binding('Array', '[]=', 'ArrayObject', 'refeq', argc: 2..3, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'any?', 'ArrayObject', 'any', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'at', 'ArrayObject', 'at', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'assoc', 'ArrayObject', 'assoc', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'bsearch', 'ArrayObject', 'bsearch', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'bsearch_index', 'ArrayObject', 'bsearch_index', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'clear', 'ArrayObject', 'clear', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'collect', 'ArrayObject', 'map', argc: 0, pass_env: true, pass_block: true, aliases: ['map'], return_type: :Object)
gen.binding('Array', 'collect!', 'ArrayObject', 'map_in_place', argc: 0, pass_env: true, pass_block: true, aliases: ['map!'], return_type: :Object)
gen.binding('Array', 'concat', 'ArrayObject', 'concat', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'compact', 'ArrayObject', 'compact', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'compact!', 'ArrayObject', 'compact_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'cycle', 'ArrayObject', 'cycle', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'deconstruct', 'ArrayObject', 'itself', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Array', 'delete', 'ArrayObject', 'delete_item', argc: 1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'delete_at', 'ArrayObject', 'delete_at', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'delete_if', 'ArrayObject', 'delete_if', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'difference', 'ArrayObject', 'difference', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'dig', 'ArrayObject', 'dig', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'drop', 'ArrayObject', 'drop', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'drop_while', 'ArrayObject', 'drop_while', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'each', 'ArrayObject', 'each', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'each_index', 'ArrayObject', 'each_index', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'empty?', 'ArrayObject', 'is_empty', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Array', 'fetch', 'ArrayObject', 'fetch', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'fill', 'ArrayObject', 'fill', argc: 0..3, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'find_index', 'ArrayObject', 'index', argc: 0..1, pass_env: true, pass_block: true, aliases: ['index'], return_type: :Object)
gen.binding('Array', 'first', 'ArrayObject', 'first', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'flatten', 'ArrayObject', 'flatten', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'flatten!', 'ArrayObject', 'flatten_in_place', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'hash', 'ArrayObject', 'hash', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'include?', 'ArrayObject', 'include', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Array', 'intersection', 'ArrayObject', 'intersection', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'intersect?', 'ArrayObject', 'intersects', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Array', 'initialize', 'ArrayObject', 'initialize', argc: 0..2, pass_env: true, pass_block: true, return_type: :Object, visibility: :private)
gen.binding('Array', 'initialize_copy', 'ArrayObject', 'initialize_copy', argc: 1, pass_env: true, pass_block: false, aliases: ['replace'], return_type: :Object)
gen.binding('Array', 'insert', 'ArrayObject', 'insert', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'inspect', 'ArrayObject', 'inspect', argc: 0, pass_env: true, pass_block: false, aliases: ['to_s'], return_type: :Object)
gen.binding('Array', 'join', 'ArrayObject', 'join', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'keep_if', 'ArrayObject', 'keep_if', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'last', 'ArrayObject', 'last', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'length', 'ArrayObject', 'size', argc: 0, pass_env: false, pass_block: false, aliases: ['size'], return_type: :size_t)
gen.binding('Array', 'max', 'ArrayObject', 'max', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'min', 'ArrayObject', 'min', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'minmax', 'ArrayObject', 'minmax', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'none?', 'ArrayObject', 'none', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'one?', 'ArrayObject', 'one', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'pack', 'ArrayObject', 'pack', argc: 1, kwargs: [:buffer], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'pop', 'ArrayObject', 'pop', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'product', 'ArrayObject', 'product', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'push', 'ArrayObject', 'push', argc: :any, pass_env: true, pass_block: false, aliases: ['append'], return_type: :Object)
gen.binding('Array', 'rassoc', 'ArrayObject', 'rassoc', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'reject', 'ArrayObject', 'reject', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'reject!', 'ArrayObject', 'reject_in_place', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'reverse', 'ArrayObject', 'reverse', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'reverse!', 'ArrayObject', 'reverse_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'reverse_each', 'ArrayObject', 'reverse_each', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'rindex', 'ArrayObject', 'rindex', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'rotate', 'ArrayObject', 'rotate', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'rotate!', 'ArrayObject', 'rotate_in_place', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'select', 'ArrayObject', 'select', argc: 0, pass_env: true, pass_block: true, aliases: ['filter'], return_type: :Object)
gen.binding('Array', 'select!', 'ArrayObject', 'select_in_place', argc: 0, pass_env: true, pass_block: true, aliases: ['filter!'], return_type: :Object)
gen.binding('Array', 'shift', 'ArrayObject', 'shift', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'slice!', 'ArrayObject', 'slice_in_place', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'sort', 'ArrayObject', 'sort', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'sort!', 'ArrayObject', 'sort_in_place', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'sort_by!', 'ArrayObject', 'sort_by_in_place', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'sum', 'ArrayObject', 'sum', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'to_a', 'ArrayObject', 'to_a', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Array', 'to_ary', 'ArrayObject', 'to_ary', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Array', 'to_h', 'ArrayObject', 'to_h', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'union', 'ArrayObject', 'union_of', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', 'uniq!', 'ArrayObject', 'uniq_in_place', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'uniq', 'ArrayObject', 'uniq', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'unshift', 'ArrayObject', 'unshift', argc: :any, pass_env: true, pass_block: false, aliases: ['prepend'], return_type: :Object)
gen.binding('Array', 'zip', 'ArrayObject', 'zip', argc: 0.., pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Array', 'values_at', 'ArrayObject', 'values_at', argc: 0.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Array', '|', 'ArrayObject', 'union_of', argc: 1, pass_env: true, pass_block: false, return_type: :Object)

gen.static_binding_as_instance_method('BasicObject', '__id__', 'Object', 'object_id', argc: 0, pass_env: false, pass_block: false, return_type: :int)
gen.static_binding_as_instance_method('BasicObject', 'equal?', 'Object', 'equal', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('BasicObject', '__send__', 'Object', 'send', argc: 1.., pass_env: true, pass_block: true, return_type: :Object)
gen.binding('BasicObject', '!', 'Object', 'is_falsey', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('BasicObject', '==', 'Object', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('BasicObject', '!=', 'Object', 'neq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('BasicObject', 'initialize', 'Object', 'initialize', argc: 0, pass_env: true, pass_block: false, return_type: :Object, visibility: :private)
gen.binding('BasicObject', 'instance_eval', 'Object', 'instance_eval', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('BasicObject', 'instance_exec', 'Object', 'instance_exec', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('BasicObject', 'method_missing', 'Object', 'method_missing', argc: :any, pass_env: true, pass_block: true, return_type: :Object, visibility: :private)

gen.binding('Binding', 'source_location', 'BindingObject', 'source_location', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.undefine_instance_method('Class', 'module_function')
gen.binding('Class', 'initialize', 'ClassObject', 'initialize', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object, visibility: :private)
gen.binding('Class', 'superclass', 'ClassObject', 'superclass', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Class', 'singleton_class?', 'ClassObject', 'is_singleton', argc: 0, pass_env: false, pass_block: false, return_type: :bool)

gen.undefine_instance_method('Complex', 'new')
gen.binding('Complex', 'imaginary', 'ComplexObject', 'imaginary', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Complex', 'real', 'ComplexObject', 'real', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('Encoding', 'aliases', 'EncodingObject', 'aliases', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Encoding', 'default_external', 'EncodingObject', 'default_external', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Encoding', 'default_external=', 'EncodingObject', 'set_default_external', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Encoding', 'default_internal', 'EncodingObject', 'default_internal', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Encoding', 'default_internal=', 'EncodingObject', 'set_default_internal', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Encoding', 'locale_charmap', 'EncodingObject', 'locale_charmap', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('Encoding', 'find', 'EncodingObject', 'find', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Encoding', 'list', 'EncodingObject', 'list', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Encoding', 'name_list', 'EncodingObject', 'name_list', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Encoding', 'ascii_compatible?', 'EncodingObject', 'is_ascii_compatible', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Encoding', 'dummy?', 'EncodingObject', 'is_dummy', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Encoding', 'inspect', 'EncodingObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Encoding', 'names', 'EncodingObject', 'names', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Encoding', 'to_s', 'EncodingObject', 'name', argc: 0, pass_env: true, pass_block: false, aliases: ['name'], return_type: :Object)

gen.undefine_singleton_method('EnumeratorArithmeticSequence', 'new')
gen.binding('Enumerator::ArithmeticSequence', '==', 'Enumerator::ArithmeticSequenceObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Enumerator::ArithmeticSequence', 'begin', 'Enumerator::ArithmeticSequenceObject', 'begin', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Enumerator::ArithmeticSequence', 'each', 'Enumerator::ArithmeticSequenceObject', 'each', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Enumerator::ArithmeticSequence', 'end', 'Enumerator::ArithmeticSequenceObject', 'end', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Enumerator::ArithmeticSequence', 'exclude_end?', 'Enumerator::ArithmeticSequenceObject', 'exclude_end', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Enumerator::ArithmeticSequence', 'hash', 'Enumerator::ArithmeticSequenceObject', 'hash', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Enumerator::ArithmeticSequence', 'inspect', 'Enumerator::ArithmeticSequenceObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Enumerator::ArithmeticSequence', 'last', 'Enumerator::ArithmeticSequenceObject', 'last', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Enumerator::ArithmeticSequence', 'size', 'Enumerator::ArithmeticSequenceObject', 'size', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Enumerator::ArithmeticSequence', 'step', 'Enumerator::ArithmeticSequenceObject', 'step', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.member_binding_as_class_method('ENV', '[]', 'EnvObject', 'ref', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', '[]=', 'EnvObject', 'refeq', argc: 2, pass_env: true, pass_block: false, aliases: ['store'], return_type: :Object)
gen.member_binding_as_class_method('ENV', 'assoc', 'EnvObject', 'assoc', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'clear', 'EnvObject', 'clear', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'clone', 'EnvObject', 'clone', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'delete', 'EnvObject', 'delete_key', argc: 1, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'delete_if', 'EnvObject', 'delete_if', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'dup', 'EnvObject', 'dup', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'each', 'EnvObject', 'each', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'each_key', 'EnvObject', 'each_key', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'each_pair', 'EnvObject', 'each', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'each_value', 'EnvObject', 'each_value', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'empty?', 'EnvObject', 'is_empty', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.member_binding_as_class_method('ENV', 'except', 'EnvObject', 'except', argc: 0.., pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'fetch', 'EnvObject', 'fetch', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'has_value?', 'EnvObject', 'has_value', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'include?', 'EnvObject', 'has_key', argc: 1, pass_env: true, pass_block: false, aliases: ['has_key?', 'member?', 'key?'], return_type: :bool)
gen.member_binding_as_class_method('ENV', 'inspect', 'EnvObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'invert', 'EnvObject', 'invert', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'keep_if', 'EnvObject', 'keep_if', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'key', 'EnvObject', 'key', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'keys', 'EnvObject', 'keys', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'length', 'EnvObject', 'size', argc: 0, pass_env: false, pass_block: false, return_type: :size_t)
gen.member_binding_as_class_method('ENV', 'merge!', 'EnvObject', 'update', argc: :any, pass_env: true, pass_block: true, aliases: ['update'], return_type: :Object)
gen.member_binding_as_class_method('ENV', 'rassoc', 'EnvObject', 'rassoc', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'rehash', 'EnvObject', 'rehash', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'reject', 'EnvObject', 'reject', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'reject!', 'EnvObject', 'reject_in_place', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'replace', 'EnvObject', 'replace', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'select', 'EnvObject', 'select', argc: 0, pass_env: true, pass_block: true, aliases: ['filter'], return_type: :Object)
gen.member_binding_as_class_method('ENV', 'select!', 'EnvObject', 'select_in_place', argc: 0, pass_env: true, pass_block: true, aliases: ['filter!'], return_type: :Object)
gen.member_binding_as_class_method('ENV', 'shift', 'EnvObject', 'shift', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'size', 'EnvObject', 'size', argc: 0, pass_env: false, pass_block: false, return_type: :size_t)
gen.member_binding_as_class_method('ENV', 'slice', 'EnvObject', 'slice', argc: 0.., pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'to_h', 'EnvObject', 'to_hash', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'to_hash', 'EnvObject', 'to_hash', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'to_s', 'EnvObject', 'to_s', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'value?', 'EnvObject', 'has_value', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'values', 'EnvObject', 'values', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.member_binding_as_class_method('ENV', 'values_at', 'EnvObject', 'values_at', argc: 0.., pass_env: true, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('Exception', 'exception', 'ExceptionObject', 'exception', argc: 0..1, pass_env: true, pass_klass: true, pass_block: false, return_type: :Object)
gen.binding('Exception', '==', 'ExceptionObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Exception', 'exception', 'ExceptionObject', 'exception', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Exception', 'backtrace', 'ExceptionObject', 'backtrace', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Exception', 'backtrace_locations', 'ExceptionObject', 'backtrace_locations', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Exception', 'cause', 'ExceptionObject', 'cause', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Exception', 'detailed_message', 'ExceptionObject', 'detailed_message', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Exception', 'initialize', 'ExceptionObject', 'initialize', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Exception', 'inspect', 'ExceptionObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Exception', 'message', 'ExceptionObject', 'message', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Exception', 'set_backtrace', 'ExceptionObject', 'set_backtrace', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Exception', 'to_s', 'ExceptionObject', 'to_s', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.undefine_singleton_method('FalseClass', 'new')
gen.binding('FalseClass', '&', 'FalseObject', 'and_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('FalseClass', '|', 'FalseObject', 'or_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('FalseClass', '^', 'FalseObject', 'or_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('FalseClass', 'to_s', 'FalseObject', 'to_s', argc: 0, pass_env: true, pass_block: false, aliases: ['inspect'], return_type: :Object)

gen.static_binding_as_class_method('Fiber', '[]', 'FiberObject', 'ref', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Fiber', '[]=', 'FiberObject', 'refeq', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Fiber', 'blocking', 'FiberObject', 'blocking', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_class_method('Fiber', 'blocking?', 'FiberObject', 'is_blocking_current', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Fiber', 'current', 'FiberObject', 'current', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Fiber', 'scheduler', 'FiberObject', 'scheduler', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Fiber', 'set_scheduler', 'FiberObject', 'set_scheduler', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Fiber', 'yield', 'FiberObject', 'yield', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Fiber', 'alive?', 'FiberObject', 'is_alive', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Fiber', 'blocking?', 'FiberObject', 'is_blocking', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Fiber', 'hash', 'FiberObject', 'hash', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Fiber', 'initialize', 'FiberObject', 'initialize', argc: 0, kwargs: %i[blocking storage], pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Fiber', 'resume', 'FiberObject', 'resume', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Fiber', 'status', 'FiberObject', 'status', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Fiber', 'storage', 'FiberObject', 'storage', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Fiber', 'storage=', 'FiberObject', 'set_storage', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Fiber', 'to_s', 'FiberObject', 'inspect', argc: 0, pass_env: true, pass_block: false, aliases: ['inspect'], return_type: :Object)

gen.static_binding_as_class_method('File', 'absolute_path', 'FileObject', 'absolute_path', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'absolute_path?', 'FileObject', 'is_absolute_path', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'atime', 'FileObject', 'atime', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'blockdev?', 'FileObject', 'is_blockdev', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'chardev?', 'FileObject', 'is_chardev', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'chmod', 'FileObject', 'chmod', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'chown', 'FileObject', 'chown', argc: 2.., pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'ctime', 'FileObject', 'ctime', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'delete', 'FileObject', 'unlink', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'directory?', 'FileObject', 'is_directory', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'empty?', 'FileObject', 'is_zero', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'executable?', 'FileObject', 'is_executable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'executable_real?', 'FileObject', 'is_executable_real', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'exist?', 'FileObject', 'exist', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'expand_path', 'FileObject', 'expand_path', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'file?', 'FileObject', 'is_file', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'ftype', 'FileObject', 'ftype', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'grpowned?', 'FileObject', 'is_grpowned', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'identical?', 'FileObject', 'is_identical', argc: 2, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'link', 'FileObject', 'link', argc: 2, pass_env: true, pass_block: false, return_type: :int)
gen.static_binding_as_class_method('File', 'lstat', 'FileObject', 'lstat', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'lutime', 'FileObject', 'lutime', argc: 2.., pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'mkfifo', 'FileObject', 'mkfifo', argc: 1..2, pass_env: true, pass_block: false, return_type: :int)
gen.static_binding_as_class_method('File', 'mtime', 'FileObject', 'mtime', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'owned?', 'FileObject', 'is_owned', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'path', 'FileObject', 'path', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'pipe?', 'FileObject', 'is_pipe', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'readable?', 'FileObject', 'is_readable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'readable_real?', 'FileObject', 'is_readable_real', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'readlink', 'FileObject', 'readlink', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
# NATFIXME: realdirpath is subtly different from realpath and should bind to a unique function
gen.static_binding_as_class_method('File', 'realdirpath', 'FileObject', 'realpath', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'realpath', 'FileObject', 'realpath', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'rename', 'FileObject', 'rename', argc: 2, pass_env: true, pass_block: false, return_type: :int)
gen.static_binding_as_class_method('File', 'setgid?', 'FileObject', 'is_setgid', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'setuid?', 'FileObject', 'is_setuid', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'size', 'FileObject', 'size', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'size?', 'FileObject', 'is_size', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'socket?', 'FileObject', 'is_socket', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'stat', 'FileObject', 'stat', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'sticky?', 'FileObject', 'is_sticky', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'symlink', 'FileObject', 'symlink', argc: 2, pass_env: true, pass_block: false, return_type: :int)
gen.static_binding_as_class_method('File', 'symlink?', 'FileObject', 'is_symlink', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'truncate', 'FileObject', 'truncate', argc: 2, pass_env: true, pass_block: false, return_type: :int)
gen.static_binding_as_class_method('File', 'umask', 'FileObject', 'umask', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'unlink', 'FileObject', 'unlink', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'utime', 'FileObject', 'utime', argc: 2.., pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'world_readable?', 'FileObject', 'world_readable', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'world_writable?', 'FileObject', 'world_writable', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('File', 'writable?', 'FileObject', 'is_writable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'writable_real?', 'FileObject', 'is_writable_real', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('File', 'zero?', 'FileObject', 'is_zero', argc: 1, pass_env: true, pass_block: false, return_type: :bool)

gen.binding('File', 'atime', 'FileObject', 'atime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'chmod', 'FileObject', 'chmod', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'chown', 'FileObject', 'chown', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'ctime', 'FileObject', 'ctime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'flock', 'FileObject', 'flock', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'initialize', 'FileObject', 'initialize', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('File', 'lstat', 'FileObject', 'lstat', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'mtime', 'FileObject', 'mtime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'size', 'FileObject', 'size', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File', 'truncate', 'FileObject', 'truncate', argc: 1, pass_env: true, pass_block: false, return_type: :int)

gen.static_binding_as_class_method('FileTest', 'blockdev?', 'FileObject', 'is_blockdev', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'chardev?', 'FileObject', 'is_chardev', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'directory?', 'FileObject', 'is_directory', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'executable?', 'FileObject', 'is_executable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'executable_real?', 'FileObject', 'is_executable_real', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'exist?', 'FileObject', 'exist', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'file?', 'FileObject', 'is_file', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'grpowned?', 'FileObject', 'is_grpowned', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'identical?', 'FileObject', 'is_identical', argc: 2, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'owned?', 'FileObject', 'is_owned', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'pipe?', 'FileObject', 'is_pipe', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'readable?', 'FileObject', 'is_readable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'readable_real?', 'FileObject', 'is_readable_real', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'setgid?', 'FileObject', 'is_setgid', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'setuid?', 'FileObject', 'is_setuid', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'size', 'FileObject', 'size', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('FileTest', 'size?', 'FileObject', 'is_size', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('FileTest', 'socket?', 'FileObject', 'is_socket', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'sticky?', 'FileObject', 'is_sticky', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'symlink?', 'FileObject', 'is_symlink', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'world_readable?', 'FileObject', 'world_readable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'world_writable?', 'FileObject', 'world_writable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'writable?', 'FileObject', 'is_writable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'writable_real?', 'FileObject', 'is_writable_real', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('FileTest', 'zero?', 'FileObject', 'is_zero', argc: 1, pass_env: true, pass_block: false, aliases: ['empty?'], return_type: :bool)
gen.binding('File::Stat', '<=>', 'FileStatObject', 'comparison', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'atime', 'FileStatObject', 'atime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'birthtime', 'FileStatObject', 'birthtime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'blksize', 'FileStatObject', 'blksize', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'blockdev?', 'FileStatObject', 'is_blockdev', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'blocks', 'FileStatObject', 'blocks', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'chardev?', 'FileStatObject', 'is_chardev', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'ctime', 'FileStatObject', 'ctime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'dev', 'FileStatObject', 'dev', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'dev_major', 'FileStatObject', 'dev_major', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'dev_minor', 'FileStatObject', 'dev_minor', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'directory?', 'FileStatObject', 'is_directory', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'file?', 'FileStatObject', 'is_file', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'ftype', 'FileStatObject', 'ftype', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'gid', 'FileStatObject', 'gid', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'initialize', 'FileStatObject', 'initialize', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'ino', 'FileStatObject', 'ino', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'mode', 'FileStatObject', 'mode', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'mtime', 'FileStatObject', 'mtime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'nlink', 'FileStatObject', 'nlink', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'owned?', 'FileStatObject', 'is_owned', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'pipe?', 'FileStatObject', 'is_pipe', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'rdev', 'FileStatObject', 'rdev', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'rdev_major', 'FileStatObject', 'rdev_major', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'rdev_minor', 'FileStatObject', 'rdev_minor', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'setgid?', 'FileStatObject', 'is_setgid', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'setuid?', 'FileStatObject', 'is_setuid', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'socket?', 'FileStatObject', 'is_socket', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'size', 'FileStatObject', 'size', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'size?', 'FileStatObject', 'is_size', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'sticky?', 'FileStatObject', 'is_sticky', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'symlink?', 'FileStatObject', 'is_symlink', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('File::Stat', 'uid', 'FileStatObject', 'uid', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'world_readable?', 'FileStatObject', 'world_readable', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'world_writable?', 'FileStatObject', 'world_writable', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('File::Stat', 'zero?', 'FileStatObject', 'is_zero', argc: 0, pass_env: false, pass_block: false, return_type: :bool)

gen.static_binding_as_class_method('Dir', 'chdir', 'DirObject', 'chdir', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'children', 'DirObject', 'children', argc: 1, kwargs: [:encoding], pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'chroot', 'DirObject', 'chroot', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'delete', 'DirObject', 'rmdir', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'each_child', 'DirObject', 'each_child', argc: 1, kwargs: [:encoding], pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'empty?', 'DirObject', 'is_empty', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('Dir', 'entries', 'DirObject', 'entries', argc: 1, kwargs: [:encoding], pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'exist?', 'FileObject', 'is_directory', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('Dir', 'foreach', 'DirObject', 'foreach', argc: 1, kwargs: [:encoding], pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'getwd', 'DirObject', 'pwd', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
# TODO: Dir.glob
gen.static_binding_as_class_method('Dir', 'home', 'DirObject', 'home', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'mkdir', 'DirObject', 'mkdir', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'open', 'DirObject', 'open', argc: 1, kwargs: [:encoding], pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'pwd', 'DirObject', 'pwd', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'rmdir', 'DirObject', 'rmdir', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Dir', 'unlink', 'DirObject', 'rmdir', argc: 1, pass_env: true, pass_block: false, return_type: :Object)

gen.binding('Dir', 'children', 'DirObject', 'children', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Dir', 'close', 'DirObject', 'close', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Dir', 'each', 'DirObject', 'each', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Dir', 'each_child', 'DirObject', 'each_child', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Dir', 'fileno', 'DirObject', 'fileno', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.binding('Dir', 'initialize', 'DirObject', 'initialize', argc: 1, kwargs: [:encoding], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Dir', 'inspect', 'DirObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Dir', 'path', 'DirObject', 'path', argc: 0, pass_env: true, pass_block: false, aliases: ['to_path'], return_type: :Object)
gen.binding('Dir', 'pos=', 'DirObject', 'set_pos', argc: 1, pass_env: true, pass_block: false, return_type: :int)
gen.binding('Dir', 'read', 'DirObject', 'read', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Dir', 'rewind', 'DirObject', 'rewind', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Dir', 'seek', 'DirObject', 'seek', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Dir', 'tell', 'DirObject', 'tell', argc: 0, pass_env: true, pass_block: false, aliases: ['pos'], return_type: :Object)

gen.undefine_singleton_method('Float', 'new')
gen.binding('Float', '%', 'FloatObject', 'mod', argc: 1, pass_env: true, pass_block: false, aliases: ['modulo'], return_type: :Object)
gen.binding('Float', '*', 'FloatObject', 'mul', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', '**', 'FloatObject', 'pow', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', '+', 'FloatObject', 'add', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', '+@', 'FloatObject', 'uplus', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Float', '-', 'FloatObject', 'sub', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', '-@', 'FloatObject', 'uminus', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Float', '/', 'FloatObject', 'div', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', '<', 'FloatObject', 'lt', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Float', '<=', 'FloatObject', 'lte', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Float', '<=>', 'FloatObject', 'cmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', '==', 'FloatObject', 'eq', argc: 1, pass_env: true, pass_block: false, aliases: ['==='], return_type: :bool)
gen.binding('Float', '>', 'FloatObject', 'gt', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Float', '>=', 'FloatObject', 'gte', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Float', 'abs', 'FloatObject', 'abs', argc: 0, pass_env: true, pass_block: false, aliases: ['magnitude'], return_type: :Object)
gen.binding('Float', 'arg', 'FloatObject', 'arg', argc: 0, pass_env: true, pass_block: false, aliases: %w[phase angle], return_type: :Object)
gen.binding('Float', 'ceil', 'FloatObject', 'ceil', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'coerce', 'FloatObject', 'coerce', argc: 1, pass_env: true, pass_block: false, return_type: :Object, optimized: false)
gen.binding('Float', 'denominator', 'FloatObject', 'denominator', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'divmod', 'FloatObject', 'divmod', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'eql?', 'FloatObject', 'eql', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Float', 'finite?', 'FloatObject', 'is_finite', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Float', 'floor', 'FloatObject', 'floor', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'infinite?', 'FloatObject', 'is_infinite', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'nan?', 'FloatObject', 'is_nan', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Float', 'negative?', 'FloatObject', 'is_negative', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Float', 'next_float', 'FloatObject', 'next_float', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'numerator', 'FloatObject', 'numerator', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'positive?', 'FloatObject', 'is_positive', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Float', 'prev_float', 'FloatObject', 'prev_float', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'quo', 'FloatObject', 'div', argc: 1, pass_env: true, pass_block: false, aliases: ['fdiv'], return_type: :Object)
gen.binding('Float', 'round', 'FloatObject', 'round', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'to_f', 'FloatObject', 'to_f', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Float', 'to_i', 'FloatObject', 'to_i', argc: 0, pass_env: true, pass_block: false, aliases: ['to_int'], return_type: :Object)
gen.binding('Float', 'to_r', 'FloatObject', 'to_r', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'to_s', 'FloatObject', 'to_s', argc: 0, pass_env: false, pass_block: false, aliases: ['inspect'], return_type: :Object)
gen.binding('Float', 'truncate', 'FloatObject', 'truncate', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Float', 'zero?', 'FloatObject', 'is_zero', argc: 0, pass_env: false, pass_block: false, return_type: :bool)

gen.static_binding_as_class_method('GC', 'enable', 'GCModule', 'enable', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('GC', 'disable', 'GCModule', 'disable', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('GC', 'print_stats', 'GCModule', 'print_stats', argc: 0, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('GC', 'start', 'GCModule', 'start', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('Hash', '[]', 'HashObject', 'square_new', argc: :any, pass_env: true, pass_block: false, pass_klass: true, return_type: :Object)
gen.static_binding_as_class_method('Hash', 'ruby2_keywords_hash?', 'HashObject', 'is_ruby2_keywords_hash', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('Hash', 'ruby2_keywords_hash', 'HashObject', 'ruby2_keywords_hash', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', '==', 'HashObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Hash', '>=', 'HashObject', 'gte', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Hash', '>', 'HashObject', 'gt', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Hash', '<=', 'HashObject', 'lte', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Hash', '<', 'HashObject', 'lt', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Hash', '[]', 'HashObject', 'ref', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', '[]=', 'HashObject', 'refeq', argc: 2, pass_env: true, pass_block: false, aliases: ['store'], return_type: :Object)
gen.binding('Hash', 'clear', 'HashObject', 'clear', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'compact', 'HashObject', 'compact', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'compact!', 'HashObject', 'compact_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'compare_by_identity', 'HashObject', 'compare_by_identity', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'compare_by_identity?', 'HashObject', 'is_comparing_by_identity', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Hash', 'default', 'HashObject', 'get_default', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'default=', 'HashObject', 'set_default', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'default_proc', 'HashObject', 'default_proc', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'default_proc=', 'HashObject', 'set_default_proc', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'delete', 'HashObject', 'delete_key', argc: 1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Hash', 'delete_if', 'HashObject', 'delete_if', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Hash', 'dig', 'HashObject', 'dig', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'each_pair', 'HashObject', 'each', argc: 0, pass_env: true, pass_block: true, aliases: ['each'], return_type: :Object)
gen.binding('Hash', 'empty?', 'HashObject', 'is_empty', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Hash', 'eql?', 'HashObject', 'eql', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Hash', 'except', 'HashObject', 'except', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'fetch', 'HashObject', 'fetch', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Hash', 'fetch_values', 'HashObject', 'fetch_values', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Hash', 'hash', 'HashObject', 'hash', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'has_value?', 'HashObject', 'has_value', argc: 1, pass_env: true, pass_block: false, aliases: ['value?'], return_type: :bool)
gen.binding('Hash', 'initialize', 'HashObject', 'initialize', argc: 0..1, kwargs: [:capacity], pass_env: true, pass_block: true, return_type: :Object, visibility: :private)
gen.binding('Hash', 'initialize_copy', 'HashObject', 'replace', argc: 1, pass_env: true, pass_block: false, aliases: ['replace'], return_type: :Object)
gen.binding('Hash', 'inspect', 'HashObject', 'inspect', argc: 0, pass_env: true, pass_block: false, aliases: ['to_s'], return_type: :Object)
gen.binding('Hash', 'include?', 'HashObject', 'has_key', argc: 1, pass_env: true, pass_block: false, aliases: ['member?', 'has_key?', 'key?'], return_type: :bool)
gen.binding('Hash', 'keep_if', 'HashObject', 'keep_if', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Hash', 'keys', 'HashObject', 'keys', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'merge', 'HashObject', 'merge', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Hash', 'rehash', 'HashObject', 'rehash', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'size', 'HashObject', 'size', argc: 0, pass_env: true, pass_block: false, aliases: ['length'], return_type: :Object)
gen.binding('Hash', 'slice', 'HashObject', 'slice', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Hash', 'to_h', 'HashObject', 'to_h', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Hash', 'to_hash', 'HashObject', 'to_hash', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Hash', 'update', 'HashObject', 'merge_in_place', argc: :any, pass_env: true, pass_block: true, aliases: ['merge!'], return_type: :Object)
gen.binding('Hash', 'values', 'HashObject', 'values', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.undefine_singleton_method('Integer', 'new')
gen.static_binding_as_class_method('Integer', 'sqrt', 'IntegerObject', 'sqrt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '%', 'IntegerObject', 'mod', argc: 1, pass_env: true, cast_self: true, pass_block: false, aliases: ['modulo'], return_type: :Object)
gen.static_binding_as_instance_method('Integer', '&', 'IntegerObject', 'bitwise_and', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '*', 'IntegerObject', 'mul', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '**', 'IntegerObject', 'pow', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '+', 'IntegerObject', 'add', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '-', 'IntegerObject', 'sub', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '-@', 'IntegerObject', 'negate', argc: 0, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '~', 'IntegerObject', 'complement', argc: 0, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '/', 'IntegerObject', 'div', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '<=>', 'IntegerObject', 'cmp', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '!=', 'IntegerObject', 'neq', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Integer', '<', 'IntegerObject', 'lt', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Integer', '<<', 'IntegerObject', 'left_shift', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '<=', 'IntegerObject', 'lte', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Integer', '>', 'IntegerObject', 'gt', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Integer', '>>', 'IntegerObject', 'right_shift', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '[]', 'IntegerObject', 'ref', argc: 1..2, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '>=', 'IntegerObject', 'gte', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Integer', '===', 'IntegerObject', 'eq', argc: 1, pass_env: true, cast_self: true, pass_block: false, aliases: ['=='], return_type: :bool)
gen.static_binding_as_instance_method('Integer', '^', 'IntegerObject', 'bitwise_xor', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'abs', 'IntegerObject', 'abs', argc: 0, pass_env: true, cast_self: true, pass_block: false, aliases: ['magnitude'], return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'bit_length', 'IntegerObject', 'bit_length', argc: 0, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'chr', 'IntegerObject', 'chr', argc: 0..1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'ceil', 'IntegerObject', 'ceil', argc: 0..1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'coerce', 'IntegerObject', 'coerce', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'denominator', 'IntegerObject', 'denominator', argc: 0, pass_env: false, pass_self: false, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'even?', 'IntegerObject', 'is_even', argc: 0, pass_env: false, cast_self: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Integer', 'floor', 'IntegerObject', 'floor', argc: 0..1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'gcd', 'IntegerObject', 'gcd', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'inspect', 'IntegerObject', 'inspect', argc: 0, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'numerator', 'IntegerObject', 'numerator', argc: 0, pass_env: false, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'odd?', 'IntegerObject', 'is_odd', argc: 0, pass_env: false, cast_self: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Integer', 'ord', 'IntegerObject', 'ord', argc: 0, pass_env: false, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'round', 'IntegerObject', 'round', argc: 0..1, pass_env: true, cast_self: true, kwargs: [:half], pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'size', 'IntegerObject', 'size', argc: 0, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'succ', 'IntegerObject', 'succ', argc: 0, pass_env: true, cast_self: true, pass_block: false, aliases: ['next'], return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'pow', 'IntegerObject', 'powmod', argc: 1..2, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'pred', 'IntegerObject', 'pred', argc: 0, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'times', 'IntegerObject', 'times', argc: 0, pass_env: true, cast_self: true, pass_block: true, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'to_f', 'IntegerObject', 'to_f', argc: 0, pass_env: false, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'to_i', 'IntegerObject', 'to_i', argc: 0, pass_env: false, cast_self: true, pass_block: false, aliases: ['to_int'], return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'to_s', 'IntegerObject', 'to_s', argc: 0..1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'truncate', 'IntegerObject', 'truncate', argc: 0..1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', '|', 'IntegerObject', 'bitwise_or', argc: 1, pass_env: true, cast_self: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Integer', 'zero?', 'IntegerObject', 'is_zero', argc: 0, pass_env: false, cast_self: true, pass_block: false, return_type: :bool)

gen.static_binding_as_class_method('IO', 'binread', 'IoObject', 'binread', argc: 1..3, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('IO', 'binwrite', 'IoObject', 'binwrite', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('IO', 'copy_stream', 'IoObject', 'copy_stream', argc: 2..4, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('IO', 'pipe', 'IoObject', 'pipe', argc: 0..2, pass_env: true, pass_block: true, pass_klass: true, return_type: :Object)
gen.static_binding_as_class_method('IO', 'popen', 'IoObject', 'popen', argc: :any, pass_env: true, pass_block: true, pass_klass: true, return_type: :Object)
gen.static_binding_as_class_method('IO', 'read', 'IoObject', 'read_file', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('IO', 'select', 'IoObject', 'select', argc: 1..4, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('IO', 'sysopen', 'IoObject', 'sysopen', argc: 1..3, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('IO', 'try_convert', 'IoObject', 'try_convert', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('IO', 'write', 'IoObject', 'write_file', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', '<<', 'IoObject', 'ltlt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'advise', 'IoObject', 'advise', argc: 1..3, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'autoclose?', 'IoObject', 'is_autoclose', argc: 0, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('IO', 'autoclose=', 'IoObject', 'autoclose', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'binmode', 'IoObject', 'binmode', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'binmode?', 'IoObject', 'is_binmode', argc: 0, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('IO', 'close', 'IoObject', 'close', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'closed?', 'IoObject', 'is_closed', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('IO', 'close_on_exec?', 'IoObject', 'is_close_on_exec', argc: 0, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('IO', 'close_on_exec=', 'IoObject', 'set_close_on_exec', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'dup', 'IoObject', 'dup', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'each_byte', 'IoObject', 'each_byte', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('IO', 'eof?', 'IoObject', 'is_eof', argc: 0, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('IO', 'external_encoding', 'IoObject', 'external_encoding', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('IO', 'fcntl', 'IoObject', 'fcntl', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'fdatasync', 'IoObject', 'fdatasync', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.binding('IO', 'fileno', 'IoObject', 'fileno', argc: 0, pass_env: true, pass_block: false, aliases: ['to_i'], return_type: :int)
gen.binding('IO', 'fsync', 'IoObject', 'fsync', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.binding('IO', 'getbyte', 'IoObject', 'getbyte', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'getc', 'IoObject', 'getc', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'gets', 'IoObject', 'gets', argc: 0..2, kwargs: [:chomp], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'initialize', 'IoObject', 'initialize', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('IO', 'inspect', 'IoObject', 'inspect', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('IO', 'internal_encoding', 'IoObject', 'internal_encoding', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('IO', 'isatty', 'IoObject', 'isatty', argc: 0, pass_env: true, pass_block: false, aliases: ['tty?'], return_type: :bool)
gen.binding('IO', 'lineno', 'IoObject', 'lineno', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.binding('IO', 'lineno=', 'IoObject', 'set_lineno', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'path', 'IoObject', 'get_path', argc: 0, pass_env: false, pass_block: false, aliases: ['to_path'], return_type: :Object)
gen.binding('IO', 'pid', 'IoObject', 'pid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'pos=', 'IoObject', 'set_pos', argc: 1, pass_env: true, pass_block: false, return_type: :int)
gen.binding('IO', 'pread', 'IoObject', 'pread', argc: 2..3, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'print', 'IoObject', 'print', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'putc', 'IoObject', 'putc', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'puts', 'IoObject', 'puts', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'pwrite', 'IoObject', 'pwrite', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'read', 'IoObject', 'read', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'readbyte', 'IoObject', 'readbyte', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'readline', 'IoObject', 'readline', argc: 0..2, kwargs: [:chomp], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'rewind', 'IoObject', 'rewind', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.binding('IO', 'seek', 'IoObject', 'seek', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'set_encoding', 'IoObject', 'set_encoding', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'stat', 'IoObject', 'stat', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'sync', 'IoObject', 'sync', argc: 0, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('IO', 'sync=', 'IoObject', 'set_sync', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'sysread', 'IoObject', 'sysread', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'sysseek', 'IoObject', 'sysseek', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'syswrite', 'IoObject', 'syswrite', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'tell', 'IoObject', 'pos', argc: 0, pass_env: true, pass_block: false, aliases: ['pos'], return_type: :int)
gen.binding('IO', 'to_io', 'IoObject', 'to_io', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'ungetbyte', 'IoObject', 'ungetbyte', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'ungetc', 'IoObject', 'ungetc', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'wait', 'IoObject', 'wait', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'wait_readable', 'IoObject', 'wait_readable', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'wait_writable', 'IoObject', 'wait_writable', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'write', 'IoObject', 'write', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('IO', 'write_nonblock', 'IoObject', 'write_nonblock', argc: 1, kwargs: [:exception], pass_env: true, pass_block: false, return_type: :Object)

gen.module_function_binding('Kernel', '`', 'KernelModule', 'backtick', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'Array', 'KernelModule', 'Array', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', '__callee__', 'KernelModule', 'cur_callee', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'abort', 'KernelModule', 'abort_method', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'at_exit', 'KernelModule', 'at_exit', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.module_function_binding('Kernel', 'binding', 'KernelModule', 'binding', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'block_given?', 'KernelModule', 'block_given', argc: 0, pass_env: true, pass_block: true, return_type: :bool)
gen.module_function_binding('Kernel', 'caller', 'KernelModule', 'caller', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'caller_locations', 'KernelModule', 'caller_locations', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'catch', 'KernelModule', 'catch_method', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.module_function_binding('Kernel', 'Complex', 'KernelModule', 'Complex', argc: 1..2, kwargs: [:exception], pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', '__dir__', 'KernelModule', 'cur_dir', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'exit', 'KernelModule', 'exit', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'exit!', 'KernelModule', 'exit_bang', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'Integer', 'KernelModule', 'Integer', argc: 1..2, kwargs: [:exception], pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'Float', 'KernelModule', 'Float', argc: 1, kwargs: [:exception], pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'fork', 'KernelModule', 'fork', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.module_function_binding('Kernel', 'gets', 'KernelModule', 'gets', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'get_usage', 'KernelModule', 'get_usage', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'global_variables', 'KernelModule', 'global_variables', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'Hash', 'KernelModule', 'Hash', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'lambda', 'KernelModule', 'lambda', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.module_function_binding('Kernel', '__method__', 'KernelModule', 'this_method', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'p', 'KernelModule', 'p', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'print', 'KernelModule', 'print', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'proc', 'KernelModule', 'proc', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.module_function_binding('Kernel', 'puts', 'KernelModule', 'puts', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'raise', 'KernelModule', 'raise', argc: :any, pass_env: true, pass_block: false, aliases: ['fail'], return_type: :Object)
gen.module_function_binding('Kernel', 'Rational', 'KernelModule', 'Rational', argc: 1..2, kwargs: [:exception], pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'sleep', 'KernelModule', 'sleep', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'spawn', 'KernelModule', 'spawn', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'srand', 'RandomObject', 'srand', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'String', 'KernelModule', 'String', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'test', 'KernelModule', 'test', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Kernel', 'throw', 'KernelModule', 'throw_method', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'class', 'KernelModule', 'klass_obj', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'define_singleton_method', 'KernelModule', 'define_singleton_method', argc: 1, pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'dup', 'KernelModule', 'dup', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', '===', 'KernelModule', 'equal', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Kernel', '!~', 'KernelModule', 'neqtilde', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Kernel', 'eql?', 'KernelModule', 'equal', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Kernel', 'freeze', 'KernelModule', 'freeze_obj', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'hash', 'KernelModule', 'hash', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'initialize_copy', 'KernelModule', 'initialize_copy', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'inspect', 'KernelModule', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'instance_variable_defined?', 'KernelModule', 'instance_variable_defined', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Kernel', 'instance_variable_get', 'KernelModule', 'instance_variable_get', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'instance_variable_set', 'KernelModule', 'instance_variable_set', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'instance_variables', 'KernelModule', 'instance_variables', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'is_a?', 'KernelModule', 'is_a', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Kernel', 'kind_of?', 'KernelModule', 'is_a', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.static_binding_as_instance_method('Kernel', 'loop', 'KernelModule', 'loop', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'method', 'KernelModule', 'method', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'methods', 'KernelModule', 'methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'object_id', 'Object', 'object_id', argc: 0, pass_env: false, pass_block: false, return_type: :int)
gen.static_binding_as_instance_method('Kernel', 'private_methods', 'KernelModule', 'private_methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'protected_methods', 'KernelModule', 'protected_methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'public_methods', 'KernelModule', 'public_methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'remove_instance_variable', 'KernelModule', 'remove_instance_variable', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'singleton_class', 'Object', 'singleton_class', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'tap', 'KernelModule', 'tap', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.static_binding_as_instance_method('Kernel', 'to_s', 'KernelModule', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Kernel', 'clone', 'Object', 'clone', argc: 0, kwargs: [:freeze], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Kernel', 'extend', 'Object', 'extend', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Kernel', 'frozen?', 'Object', 'is_frozen', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Kernel', 'nil?', 'Object', 'is_nil', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Kernel', 'public_send', 'Object', 'public_send', argc: 1.., pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Kernel', 'respond_to?', 'Object', 'respond_to_method', argc: 1..2, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Kernel', 'respond_to_missing?', 'Object', 'respond_to_missing', argc: 2, pass_env: true, pass_block: false, return_type: :bool, visibility: :private)
gen.binding('Kernel', 'send', 'Object', 'send', argc: 1.., pass_env: true, pass_block: true, return_type: :Object)

gen.undefine_singleton_method('MatchData', 'new')
gen.undefine_singleton_method('MatchData', 'allocate')
gen.binding('MatchData', '==', 'MatchDataObject', 'eq', argc: 1, pass_env: true, pass_block: false, aliases: ['eql?'], return_type: :bool)
gen.binding('MatchData', 'begin', 'MatchDataObject', 'begin', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'byteoffset', 'MatchDataObject', 'byteoffset', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'captures', 'MatchDataObject', 'captures', argc: 0, pass_env: true, pass_block: false, aliases: ['deconstruct'], return_type: :Object)
gen.binding('MatchData', 'deconstruct_keys', 'MatchDataObject', 'deconstruct_keys', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'end', 'MatchDataObject', 'end', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'inspect', 'MatchDataObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'match', 'MatchDataObject', 'match', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'match_length', 'MatchDataObject', 'match_length', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'named_captures', 'MatchDataObject', 'named_captures', argc: 0, kwargs: [:symbolize_names], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'names', 'MatchDataObject', 'names', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'offset', 'MatchDataObject', 'offset', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'post_match', 'MatchDataObject', 'post_match', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'pre_match', 'MatchDataObject', 'pre_match', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'regexp', 'MatchDataObject', 'regexp', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'size', 'MatchDataObject', 'size', argc: 0, pass_env: false, pass_block: false, aliases: ['length'], return_type: :size_t)
gen.binding('MatchData', 'string', 'MatchDataObject', 'string', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'to_a', 'MatchDataObject', 'to_a', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'to_s', 'MatchDataObject', 'to_s', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', 'values_at', 'MatchDataObject', 'values_at', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('MatchData', '[]', 'MatchDataObject', 'ref', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)

gen.undefine_singleton_method('Method', 'new')
gen.binding('Method', '==', 'MethodObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Method', '<<', 'MethodObject', 'ltlt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Method', '>>', 'MethodObject', 'gtgt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Method', 'inspect', 'MethodObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Method', 'owner', 'MethodObject', 'owner', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Method', 'arity', 'MethodObject', 'arity', argc: 0, pass_env: false, pass_block: false, return_type: :int)
gen.binding('Method', 'call', 'MethodObject', 'call', argc: :any, pass_env: true, pass_block: true, aliases: ['[]', '==='], return_type: :Object)
gen.binding('Method', 'hash', 'MethodObject', 'hash', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Method', 'source_location', 'MethodObject', 'source_location', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Method', 'to_proc', 'MethodObject', 'to_proc', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Method', 'unbind', 'MethodObject', 'unbind', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.binding('Module', 'initialize', 'ModuleObject', 'initialize', argc: 0, pass_env: true, pass_block: true, return_type: :Object, visibility: :private)
gen.binding('Module', '===', 'ModuleObject', 'eqeqeq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Module', 'alias_method', 'ModuleObject', 'alias_method', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'ancestors', 'ModuleObject', 'ancestors', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'attr', 'ModuleObject', 'attr', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'attr_accessor', 'ModuleObject', 'attr_accessor', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'attr_reader', 'ModuleObject', 'attr_reader', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'attr_writer', 'ModuleObject', 'attr_writer', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'autoload?', 'ModuleObject', 'is_autoload', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'class_variable_defined?', 'ModuleObject', 'class_variable_defined', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Module', 'class_variable_get', 'ModuleObject', 'class_variable_get', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'class_variable_set', 'ModuleObject', 'class_variable_set', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'class_variables', 'ModuleObject', 'class_variables', argc: 0..1, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Module', 'const_defined?', 'ModuleObject', 'const_defined', argc: 1..2, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Module', 'const_get', 'ModuleObject', 'const_get', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'const_missing', 'ModuleObject', 'const_missing', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'const_set', 'ModuleObject', 'const_set', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'constants', 'ModuleObject', 'constants', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'define_method', 'ModuleObject', 'define_method', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Module', 'deprecate_constant', 'ModuleObject', 'deprecate_constant', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'extend', 'Object', 'extend', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'include', 'ModuleObject', 'include', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'include?', 'ModuleObject', 'does_include_module', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Module', 'included_modules', 'ModuleObject', 'included_modules', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'instance_method', 'ModuleObject', 'instance_method', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'instance_methods', 'ModuleObject', 'instance_methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'method_defined?', 'ModuleObject', 'is_method_defined', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Module', 'module_eval', 'ModuleObject', 'module_eval', argc: 0, pass_env: true, pass_block: true, aliases: ['class_eval'], return_type: :Object)
gen.binding('Module', 'module_exec', 'ModuleObject', 'module_exec', argc: :any, pass_env: true, pass_block: true, aliases: ['class_exec'], return_type: :Object)
gen.binding('Module', 'module_function', 'ModuleObject', 'module_function', argc: :any, pass_env: true, pass_block: false, return_type: :Object, visibility: :private)
gen.binding('Module', 'name', 'ModuleObject', 'name', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'prepend', 'ModuleObject', 'prepend', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'private', 'ModuleObject', 'private_method', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'private_class_method', 'ModuleObject', 'private_class_method', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'private_constant', 'ModuleObject', 'private_constant', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'private_instance_methods', 'ModuleObject', 'private_instance_methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'protected', 'ModuleObject', 'protected_method', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'protected_instance_methods', 'ModuleObject', 'protected_instance_methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'public', 'ModuleObject', 'public_method', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'public_class_method', 'ModuleObject', 'public_class_method', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'public_constant', 'ModuleObject', 'public_constant', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'public_instance_methods', 'ModuleObject', 'public_instance_methods', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'public_instance_method', 'ModuleObject', 'public_instance_method', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'remove_class_variable', 'ModuleObject', 'remove_class_variable', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'remove_const', 'ModuleObject', 'remove_const', argc: 1, pass_env: true, pass_block: false, return_type: :Object, visibility: :private)
gen.binding('Module', 'remove_method', 'ModuleObject', 'remove_method', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'ruby2_keywords', 'ModuleObject', 'ruby2_keywords', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Module', 'to_s', 'ModuleObject', 'inspect', argc: 0, pass_env: true, pass_block: false, aliases: ['inspect'], return_type: :Object)
gen.binding('Module', 'undef_method', 'ModuleObject', 'undef_method', argc: :any, pass_env: true, pass_block: false, return_type: :Object)

gen.undefine_singleton_method('NilClass', 'new')
gen.binding('NilClass', '&', 'NilObject', 'and_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('NilClass', '|', 'NilObject', 'or_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('NilClass', '^', 'NilObject', 'or_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('NilClass', '=~', 'NilObject', 'eqtilde', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'inspect', 'NilObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'rationalize', 'NilObject', 'rationalize', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'to_a', 'NilObject', 'to_a', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'to_c', 'NilObject', 'to_c', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'to_f', 'NilObject', 'to_f', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'to_h', 'NilObject', 'to_h', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'to_i', 'NilObject', 'to_i', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'to_r', 'NilObject', 'to_r', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('NilClass', 'to_s', 'NilObject', 'to_s', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.binding('Object', 'nil?', 'Object', 'is_nil', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Object', 'itself', 'Object', 'itself', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('ObjectSpace', 'define_finalizer', 'ObjectSpaceModule', 'define_finalizer', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)

gen.binding('Proc', '==', 'ProcObject', 'equal_value', argc: 1, pass_env: false, pass_block: false, aliases: ['eql?'], return_type: :bool)
gen.binding('Proc', '<<', 'ProcObject', 'ltlt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Proc', '>>', 'ProcObject', 'gtgt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Proc', 'initialize', 'ProcObject', 'initialize', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Proc', 'arity', 'ProcObject', 'arity', argc: 0, pass_env: false, pass_block: false, return_type: :int)
gen.binding('Proc', 'call', 'ProcObject', 'call', argc: :any, pass_env: true, pass_block: true, aliases: ['[]', '===', 'yield'], return_type: :Object)
gen.binding('Proc', 'lambda?', 'ProcObject', 'is_lambda', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Proc', 'ruby2_keywords', 'ProcObject', 'ruby2_keywords', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Proc', 'source_location', 'ProcObject', 'source_location', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Proc', 'to_proc', 'ProcObject', 'to_proc', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Proc', 'to_s', 'ProcObject', 'to_s', argc: 0, pass_env: true, pass_block: false, aliases: ['inspect'], return_type: :Object)

gen.module_function_binding('Process', 'abort', 'KernelModule', 'abort_method', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'clock_gettime', 'ProcessModule', 'clock_gettime', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'egid', 'ProcessModule', 'egid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'egid=', 'ProcessModule', 'setegid', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'euid', 'ProcessModule', 'euid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'euid=', 'ProcessModule', 'seteuid', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'exit', 'KernelModule', 'exit', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'exit!', 'KernelModule', 'exit_bang', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'fork', 'KernelModule', 'fork', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.module_function_binding('Process', 'groups', 'ProcessModule', 'groups', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'getpgid', 'ProcessModule', 'getpgid', argc: 1, pass_env: true, pass_block: false, return_type: :int)
gen.module_function_binding('Process', 'getpgrp', 'ProcessModule', 'getpgrp', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.module_function_binding('Process', 'getpriority', 'ProcessModule', 'getpriority', argc: 2, pass_env: true, pass_block: false, return_type: :int)
gen.module_function_binding('Process', 'getrlimit', 'ProcessModule', 'getrlimit', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'getsid', 'ProcessModule', 'getsid', argc: 0..1, pass_env: true, pass_block: false, return_type: :int)
gen.module_function_binding('Process', 'gid', 'ProcessModule', 'gid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'gid=', 'ProcessModule', 'setgid', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'kill', 'ProcessModule', 'kill', argc: 2.., pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'maxgroups', 'ProcessModule', 'maxgroups', argc: 0, pass_env: false, pass_block: false, return_type: :int)
gen.module_function_binding('Process', 'maxgroups=', 'ProcessModule', 'setmaxgroups', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'pid', 'ProcessModule', 'pid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'ppid', 'ProcessModule', 'ppid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'setpgrp', 'ProcessModule', 'setpgrp', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.module_function_binding('Process', 'setsid', 'ProcessModule', 'setsid', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.module_function_binding('Process', 'spawn', 'KernelModule', 'spawn', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'times', 'ProcessModule', 'times', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'uid', 'ProcessModule', 'uid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'uid=', 'ProcessModule', 'setuid', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process', 'wait', 'ProcessModule', 'wait', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::GID', 'eid', 'ProcessModule', 'egid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::GID', 'rid', 'ProcessModule', 'gid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::Sys', 'getegid', 'ProcessModule', 'egid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::Sys', 'geteuid', 'ProcessModule', 'euid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::Sys', 'getgid', 'ProcessModule', 'gid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::Sys', 'getuid', 'ProcessModule', 'uid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::UID', 'eid', 'ProcessModule', 'euid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Process::UID', 'rid', 'ProcessModule', 'uid', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('Random', 'new_seed', 'RandomObject', 'new_seed', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Random', 'srand', 'RandomObject', 'srand', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Random', 'urandom', 'RandomObject', 'urandom', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Random', 'initialize', 'RandomObject', 'initialize', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object, visibility: :private)
gen.binding('Random', 'bytes', 'RandomObject', 'bytes', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Random', 'rand', 'RandomObject', 'rand', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Random', 'seed', 'RandomObject', 'seed', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.binding('Range', '%', 'RangeObject', 'step', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Range', '==', 'RangeObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Range', 'begin', 'RangeObject', 'begin', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Range', 'bsearch', 'RangeObject', 'bsearch', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Range', 'end', 'RangeObject', 'end', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Range', 'each', 'RangeObject', 'each', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Range', 'eql?', 'RangeObject', 'eql', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Range', 'exclude_end?', 'RangeObject', 'exclude_end', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Range', 'first', 'RangeObject', 'first', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Range', 'initialize', 'RangeObject', 'initialize', argc: 2..3, pass_env: true, pass_block: false, return_type: :Object, visibility: :private)
gen.binding('Range', 'inspect', 'RangeObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Range', 'last', 'RangeObject', 'last', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Range', 'member?', 'RangeObject', 'include', argc: 1, pass_env: true, pass_block: false, aliases: ['include?'], return_type: :bool)
gen.binding('Range', 'step', 'RangeObject', 'step', argc: 0..1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Range', 'to_a', 'RangeObject', 'to_a', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Range', 'to_s', 'RangeObject', 'to_s', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.undefine_singleton_method('Rational', 'new')
gen.binding('Rational', '*', 'RationalObject', 'mul', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', '**', 'RationalObject', 'pow', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', '+', 'RationalObject', 'add', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', '-', 'RationalObject', 'sub', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', '/', 'RationalObject', 'div', argc: 1, pass_env: true, pass_block: false, aliases: ['quo'], return_type: :Object)
gen.binding('Rational', '<=>', 'RationalObject', 'cmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', '==', 'RationalObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Rational', 'coerce', 'RationalObject', 'coerce', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'denominator', 'RationalObject', 'denominator', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'floor', 'RationalObject', 'floor', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'inspect', 'RationalObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'marshal_dump', 'RationalObject', 'marshal_dump', argc: 0, pass_env: true, pass_block: false, return_type: :Object, visibility: :private)
gen.binding('Rational', 'numerator', 'RationalObject', 'numerator', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'rationalize', 'RationalObject', 'rationalize', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'to_f', 'RationalObject', 'to_f', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'to_i', 'RationalObject', 'to_i', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'to_r', 'RationalObject', 'to_r', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Rational', 'to_s', 'RationalObject', 'to_s', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'truncate', 'RationalObject', 'truncate', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Rational', 'zero?', 'RationalObject', 'is_zero', argc: 0, pass_env: false, pass_block: false, return_type: :bool)

gen.static_binding_as_class_method('Regexp', 'compile', 'RegexpObject', 'compile', argc: 1..2, pass_env: true, pass_block: false, pass_klass: true, return_type: :Object)
gen.static_binding_as_class_method('Regexp', 'escape', 'RegexpObject', 'quote', argc: 1, pass_env: true, pass_block: false, pass_klass: false, aliases: ['quote'], return_type: :Object)
gen.static_binding_as_class_method('Regexp', 'last_match', 'RegexpObject', 'last_match', argc: 0..1, pass_env: true, pass_block: false, pass_klass: false, return_type: :Object)
gen.static_binding_as_class_method('Regexp', 'try_convert', 'RegexpObject', 'try_convert', argc: 1, pass_env: true, pass_block: false, pass_klass: false, return_type: :Object)
gen.static_binding_as_class_method('Regexp', 'union', 'RegexpObject', 'regexp_union', argc: :any, pass_env: true, pass_block: false, pass_klass: false, return_type: :Object)
gen.binding('Regexp', '===', 'RegexpObject', 'eqeqeq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Regexp', '=~', 'RegexpObject', 'eqtilde', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Regexp', '~', 'RegexpObject', 'tilde', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Regexp', 'casefold?', 'RegexpObject', 'casefold', argc: 0, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Regexp', 'encoding', 'RegexpObject', 'encoding', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Regexp', 'eql?', 'RegexpObject', 'eq', argc: 1, pass_env: true, pass_block: false, aliases: ['=='], return_type: :bool)
gen.binding('Regexp', 'fixed_encoding?', 'RegexpObject', 'is_fixed_encoding', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Regexp', 'hash', 'RegexpObject', 'hash', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Regexp', 'initialize', 'RegexpObject', 'initialize', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object, visibility: :private)
gen.binding('Regexp', 'inspect', 'RegexpObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Regexp', 'match', 'RegexpObject', 'match', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Regexp', 'match?', 'RegexpObject', 'has_match', argc: 1..2, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Regexp', 'named_captures', 'RegexpObject', 'named_captures', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Regexp', 'names', 'RegexpObject', 'names', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Regexp', 'options', 'RegexpObject', 'options', argc: 0, pass_env: true, pass_block: false, return_type: :int)
gen.binding('Regexp', 'source', 'RegexpObject', 'source', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Regexp', 'to_s', 'RegexpObject', 'to_s', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.module_function_binding('Signal', 'list', 'SignalModule', 'list', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.module_function_binding('Signal', 'signame', 'SignalModule', 'signame', argc: 1, pass_env: true, pass_block: false, return_type: :Object)

gen.binding('String', '*', 'StringObject', 'mul', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', '+', 'StringObject', 'add', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', '+@', 'StringObject', 'uplus', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', '-@', 'StringObject', 'uminus', argc: 0, pass_env: true, pass_block: false, aliases: ['dedup'], return_type: :Object)
gen.binding('String', '<<', 'StringObject', 'ltlt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', '<=>', 'StringObject', 'cmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', '==', 'StringObject', 'eq', argc: 1, pass_env: true, pass_block: false, aliases: ['==='], return_type: :bool)
gen.binding('String', '=~', 'StringObject', 'eqtilde', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', '[]', 'StringObject', 'ref', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', '[]=', 'StringObject', 'refeq', argc: 1..3, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'ascii_only?', 'StringObject', 'is_ascii_only', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('String', 'append_as_bytes', 'StringObject', 'append_as_bytes', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'b', 'StringObject', 'b', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'bytes', 'StringObject', 'bytes', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'byteindex', 'StringObject', 'byteindex', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'byterindex', 'StringObject', 'byterindex', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'byteslice', 'StringObject', 'byteslice', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'bytesplice', 'StringObject', 'bytesplice', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'bytesize', 'StringObject', 'bytesize', argc: 0, pass_env: false, pass_block: false, return_type: :size_t)
gen.binding('String', 'capitalize', 'StringObject', 'capitalize', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'capitalize!', 'StringObject', 'capitalize_in_place', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'casecmp', 'StringObject', 'casecmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'casecmp?', 'StringObject', 'is_casecmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'center', 'StringObject', 'center', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'chars', 'StringObject', 'chars', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'chomp', 'StringObject', 'chomp', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'chomp!', 'StringObject', 'chomp_in_place', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'chop', 'StringObject', 'chop', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'chop!', 'StringObject', 'chop_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'chr', 'StringObject', 'chr', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'clear', 'StringObject', 'clear', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'codepoints', 'StringObject', 'codepoints', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'concat', 'StringObject', 'concat', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'count', 'StringObject', 'count', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'delete', 'StringObject', 'delete_str', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'delete!', 'StringObject', 'delete_in_place', argc: 1.., pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'dump', 'StringObject', 'dump', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'crypt', 'StringObject', 'crypt', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'delete_prefix', 'StringObject', 'delete_prefix', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'delete_prefix!', 'StringObject', 'delete_prefix_in_place', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'delete_suffix', 'StringObject', 'delete_suffix', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'delete_suffix!', 'StringObject', 'delete_suffix_in_place', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'downcase', 'StringObject', 'downcase', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'downcase!', 'StringObject', 'downcase_in_place', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'each_byte', 'StringObject', 'each_byte', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'each_char', 'StringObject', 'each_char', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'each_codepoint', 'StringObject', 'each_codepoint', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'each_grapheme_cluster', 'StringObject', 'each_grapheme_cluster', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'each_line', 'StringObject', 'each_line', argc: 0..1, kwargs: [:chomp], pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'empty?', 'StringObject', 'is_empty', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('String', 'encode', 'StringObject', 'encode', argc: 0..2, kwargs: true, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'encode!', 'StringObject', 'encode_in_place', argc: 0..2, kwargs: true, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'encoding', 'StringObject', 'encoding', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('String', 'end_with?', 'StringObject', 'end_with', argc: :any, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('String', 'eql?', 'StringObject', 'eql', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('String', 'force_encoding', 'StringObject', 'force_encoding', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'getbyte', 'StringObject', 'getbyte', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'grapheme_clusters', 'StringObject', 'grapheme_clusters', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'gsub', 'StringObject', 'gsub', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'gsub!', 'StringObject', 'gsub_in_place', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'hex', 'StringObject', 'hex', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'include?', 'StringObject', 'include', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('String', 'index', 'StringObject', 'index', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'initialize', 'StringObject', 'initialize', argc: 0..1, kwargs: %i[encoding capacity], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'initialize_copy', 'StringObject', 'initialize_copy', argc: 1, pass_env: true, pass_block: false, aliases: ['replace'], return_type: :Object)
gen.binding('String', 'insert', 'StringObject', 'insert', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'inspect', 'StringObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'intern', 'StringObject', 'to_sym', argc: 0, pass_env: true, pass_block: false, aliases: ['to_sym'], return_type: :Object)
gen.binding('String', 'length', 'StringObject', 'size', argc: 0, pass_env: true, pass_block: false, aliases: ['size'], return_type: :Object)
gen.binding('String', 'lines', 'StringObject', 'lines', argc: 0..1, kwargs: [:chomp], pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'ljust', 'StringObject', 'ljust', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'lstrip', 'StringObject', 'lstrip', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'lstrip!', 'StringObject', 'lstrip_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'match', 'StringObject', 'match', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'match?', 'StringObject', 'has_match', argc: 1..2, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('String', 'prepend', 'StringObject', 'prepend', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'ord', 'StringObject', 'ord', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'partition', 'StringObject', 'partition', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'reverse', 'StringObject', 'reverse', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'reverse!', 'StringObject', 'reverse_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'rindex', 'StringObject', 'rindex', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'rjust', 'StringObject', 'rjust', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'rstrip', 'StringObject', 'rstrip', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'rstrip!', 'StringObject', 'rstrip_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'scan', 'StringObject', 'scan', argc: 1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'setbyte', 'StringObject', 'setbyte', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'slice!', 'StringObject', 'slice_in_place', argc: 1..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'split', 'StringObject', 'split', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'start_with?', 'StringObject', 'start_with', argc: :any, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('String', 'strip', 'StringObject', 'strip', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'strip!', 'StringObject', 'strip_in_place', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'sub', 'StringObject', 'sub', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'sub!', 'StringObject', 'sub_in_place', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'succ', 'StringObject', 'successive', argc: 0, pass_env: true, pass_block: false, aliases: ['next'], return_type: :Object)
gen.binding('String', 'succ!', 'StringObject', 'successive_in_place', argc: 0, pass_env: true, pass_block: false, aliases: ['next!'], return_type: :Object)
gen.binding('String', 'swapcase', 'StringObject', 'swapcase', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'swapcase!', 'StringObject', 'swapcase_in_place', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'sum', 'StringObject', 'sum', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'to_f', 'StringObject', 'to_f', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'to_i', 'StringObject', 'to_i', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'to_r', 'StringObject', 'to_r', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'to_s', 'StringObject', 'to_s', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('String', 'to_str', 'StringObject', 'to_s', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('String', 'tr', 'StringObject', 'tr', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'tr!', 'StringObject', 'tr_in_place', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('String', 'try_convert', 'StringObject', 'try_convert', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'unpack', 'StringObject', 'unpack', argc: 1, kwargs: [:offset], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'unpack1', 'StringObject', 'unpack1', argc: 1, kwargs: [:offset], pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'upcase', 'StringObject', 'upcase', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'upcase!', 'StringObject', 'upcase_in_place', argc: 0..2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('String', 'upto', 'StringObject', 'upto', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('String', 'valid_encoding?', 'StringObject', 'valid_encoding', argc: 0, pass_env: false, pass_block: false, return_type: :bool)

gen.undefine_singleton_method('Symbol', 'new')
gen.static_binding_as_class_method('Symbol', 'all_symbols', 'SymbolObject', 'all_symbols', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', '<=>', 'SymbolObject', 'cmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', '=~', 'SymbolObject', 'eqtilde', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', '[]', 'SymbolObject', 'ref', argc: 1..2, pass_env: true, pass_block: false, aliases: ['slice'], return_type: :Object)
gen.binding('Symbol', 'capitalize', 'SymbolObject', 'capitalize', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'casecmp', 'SymbolObject', 'casecmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'casecmp?', 'SymbolObject', 'is_casecmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'downcase', 'SymbolObject', 'downcase', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'empty?', 'SymbolObject', 'is_empty', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Symbol', 'encoding', 'SymbolObject', 'encoding', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'end_with?', 'SymbolObject', 'end_with', argc: :any, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Symbol', 'inspect', 'SymbolObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'length', 'SymbolObject', 'length', argc: 0, pass_env: true, pass_block: false, aliases: ['size'], return_type: :Object)
gen.binding('Symbol', 'match', 'SymbolObject', 'match', argc: 1, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Symbol', 'match?', 'SymbolObject', 'has_match', argc: 1..2, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Symbol', 'name', 'SymbolObject', 'name', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'start_with?', 'SymbolObject', 'start_with', argc: :any, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Symbol', 'succ', 'SymbolObject', 'succ', argc: 0, pass_env: true, pass_block: false, aliases: ['next'], return_type: :Object)
gen.binding('Symbol', 'swapcase', 'SymbolObject', 'swapcase', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'to_proc', 'SymbolObject', 'to_proc', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Symbol', 'to_s', 'SymbolObject', 'to_s', argc: 0, pass_env: true, pass_block: false, aliases: ['id2name'], return_type: :Object)
gen.binding('Symbol', 'to_sym', 'SymbolObject', 'to_sym', argc: 0, pass_env: true, pass_block: false, aliases: ['intern'], return_type: :Object)
gen.binding('Symbol', 'upcase', 'SymbolObject', 'upcase', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('Thread', 'abort_on_exception', 'ThreadObject', 'global_abort_on_exception', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('Thread', 'abort_on_exception=', 'ThreadObject', 'set_global_abort_on_exception', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('Thread', 'current', 'ThreadObject', 'current', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Thread', 'kill', 'ThreadObject', 'thread_kill', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Thread', 'exit', 'ThreadObject', 'exit', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Thread', 'list', 'ThreadObject', 'list', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Thread', 'main', 'ThreadObject', 'main', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Thread', 'pass', 'ThreadObject', 'pass', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Thread', 'report_on_exception', 'ThreadObject', 'default_report_on_exception', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('Thread', 'report_on_exception=', 'ThreadObject', 'set_default_report_on_exception', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.static_binding_as_class_method('Thread', 'stop', 'ThreadObject', 'stop', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', '[]', 'ThreadObject', 'ref', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', '[]=', 'ThreadObject', 'refeq', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'abort_on_exception', 'ThreadObject', 'abort_on_exception', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread', 'abort_on_exception=', 'ThreadObject', 'set_abort_on_exception', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread', 'alive?', 'ThreadObject', 'is_alive', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread', 'fetch', 'ThreadObject', 'fetch', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Thread', 'group', 'ThreadObject', 'group', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Thread', 'initialize', 'ThreadObject', 'initialize', argc: :any, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Thread', 'join', 'ThreadObject', 'join', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'key?', 'ThreadObject', 'has_key', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Thread', 'keys', 'ThreadObject', 'keys', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'kill', 'ThreadObject', 'kill', argc: 0, pass_env: true, pass_block: false, aliases: %w[exit terminate], return_type: :Object)
gen.binding('Thread', 'name', 'ThreadObject', 'name', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'name=', 'ThreadObject', 'set_name', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'priority', 'ThreadObject', 'priority', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'priority=', 'ThreadObject', 'set_priority', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'raise', 'ThreadObject', 'raise', argc: :any, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'report_on_exception', 'ThreadObject', 'report_on_exception', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread', 'report_on_exception=', 'ThreadObject', 'set_report_on_exception', argc: 1, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread', 'run', 'ThreadObject', 'run', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'status', 'ThreadObject', 'status', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'stop?', 'ThreadObject', 'is_stopped', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread', 'thread_variable?', 'ThreadObject', 'has_thread_variable', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Thread', 'thread_variable_get', 'ThreadObject', 'thread_variable_get', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'thread_variable_set', 'ThreadObject', 'thread_variable_set', argc: 2, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'thread_variables', 'ThreadObject', 'thread_variables', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'to_s', 'ThreadObject', 'to_s', argc: 0, pass_env: true, pass_block: false, aliases: ['inspect'], return_type: :Object)
gen.binding('Thread', 'value', 'ThreadObject', 'value', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread', 'wakeup', 'ThreadObject', 'wakeup', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.binding('ThreadGroup', 'add', 'ThreadGroupObject', 'add', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('ThreadGroup', 'enclose', 'ThreadGroupObject', 'enclose', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('ThreadGroup', 'enclosed?', 'ThreadGroupObject', 'is_enclosed', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('ThreadGroup', 'list', 'ThreadGroupObject', 'list', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.undefine_singleton_method('ThreadBacktraceLocation', 'new')
gen.binding('Thread::Backtrace::Location', 'absolute_path', 'Thread::Backtrace::LocationObject', 'absolute_path', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread::Backtrace::Location', 'inspect', 'Thread::Backtrace::LocationObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread::Backtrace::Location', 'lineno', 'Thread::Backtrace::LocationObject', 'lineno', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Thread::Backtrace::Location', 'path', 'Thread::Backtrace::LocationObject', 'path', argc: 0, pass_env: false, pass_block: false, return_type: :Object)
gen.binding('Thread::Backtrace::Location', 'to_s', 'Thread::Backtrace::LocationObject', 'to_s', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.binding('Thread::Mutex', 'lock', 'Thread::MutexObject', 'lock', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread::Mutex', 'locked?', 'Thread::MutexObject', 'is_locked', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread::Mutex', 'owned?', 'Thread::MutexObject', 'is_owned', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread::Mutex', 'sleep', 'Thread::MutexObject', 'sleep', argc: 0..1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Thread::Mutex', 'synchronize', 'Thread::MutexObject', 'synchronize', argc: 0, pass_env: true, pass_block: true, return_type: :Object)
gen.binding('Thread::Mutex', 'try_lock', 'Thread::MutexObject', 'try_lock', argc: 0, pass_env: false, pass_block: false, return_type: :bool)
gen.binding('Thread::Mutex', 'unlock', 'Thread::MutexObject', 'unlock', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.static_binding_as_class_method('Time', 'at', 'TimeObject', 'at', argc: 1..3, kwargs: [:in], pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Time', 'local', 'TimeObject', 'local', argc: 1..7, pass_env: true, pass_block: false, aliases: ['mktime'], return_type: :Object)
gen.static_binding_as_class_method('Time', 'new', 'TimeObject', 'initialize', argc: 0..7, kwargs: [:in], pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Time', 'now', 'TimeObject', 'now', argc: 0, kwargs: [:in], pass_env: true, pass_block: false, return_type: :Object)
gen.static_binding_as_class_method('Time', 'utc', 'TimeObject', 'utc', argc: 1..7, pass_env: true, pass_block: false, aliases: ['gm'], return_type: :Object)
gen.binding('Time', '+', 'TimeObject', 'add', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', '-', 'TimeObject', 'minus', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', '<=>', 'TimeObject', 'cmp', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'asctime', 'TimeObject', 'asctime', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'eql?', 'TimeObject', 'eql', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('Time', 'getutc', 'TimeObject', 'to_utc', argc: 0, pass_env: true, pass_block: false, aliases: ['getgm'], return_type: :Object)
gen.binding('Time', 'gmtoff', 'TimeObject', 'utc_offset', argc: 0, pass_env: true, pass_block: false, aliases: %w[gmt_offset utc_offset], return_type: :Object)
gen.binding('Time', 'isdst', 'TimeObject', 'isdst', argc: 0, pass_env: true, pass_block: false, aliases: ['dst?'], return_type: :bool)
gen.binding('Time', 'hour', 'TimeObject', 'hour', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'inspect', 'TimeObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'mday', 'TimeObject', 'mday', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'min', 'TimeObject', 'min', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'month', 'TimeObject', 'month', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'nsec', 'TimeObject', 'nsec', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'sec', 'TimeObject', 'sec', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'strftime', 'TimeObject', 'strftime', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'subsec', 'TimeObject', 'subsec', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'to_a', 'TimeObject', 'to_a', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'to_f', 'TimeObject', 'to_f', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'to_i', 'TimeObject', 'to_i', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'to_r', 'TimeObject', 'to_r', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'to_s', 'TimeObject', 'to_s', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'usec', 'TimeObject', 'usec', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'utc?', 'TimeObject', 'is_utc', argc: 0, pass_env: true, pass_block: false, aliases: ['gmt?'], return_type: :bool)
gen.binding('Time', 'wday', 'TimeObject', 'wday', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'yday', 'TimeObject', 'yday', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'year', 'TimeObject', 'year', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('Time', 'zone', 'TimeObject', 'zone', argc: 0, pass_env: true, pass_block: false, return_type: :Object)

gen.undefine_singleton_method('TrueClass', 'new')
gen.binding('TrueClass', '&', 'TrueObject', 'and_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('TrueClass', '|', 'TrueObject', 'or_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('TrueClass', '^', 'TrueObject', 'xor_method', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('TrueClass', 'to_s', 'TrueObject', 'to_s', argc: 0, pass_env: true, pass_block: false, aliases: ['inspect'], return_type: :Object)

gen.undefine_singleton_method('UnboundMethod', 'new')
gen.binding('UnboundMethod', '==', 'UnboundMethodObject', 'eq', argc: 1, pass_env: true, pass_block: false, return_type: :bool)
gen.binding('UnboundMethod', 'arity', 'UnboundMethodObject', 'arity', argc: 0, pass_env: false, pass_block: false, return_type: :int)
gen.binding('UnboundMethod', 'bind', 'UnboundMethodObject', 'bind', argc: 1, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('UnboundMethod', 'bind_call', 'UnboundMethodObject', 'bind_call', argc: 1.., pass_env: true, pass_block: true, return_type: :Object)
gen.binding('UnboundMethod', 'inspect', 'UnboundMethodObject', 'inspect', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('UnboundMethod', 'name', 'UnboundMethodObject', 'name', argc: 0, pass_env: true, pass_block: false, return_type: :Object)
gen.binding('UnboundMethod', 'owner', 'UnboundMethodObject', 'owner', argc: 0, pass_env: false, pass_block: false, return_type: :Object)

gen.member_binding_as_class_method('main_obj', 'define_method', 'Object', 'main_obj_define_method', argc: 1..2, pass_env: true, pass_block: true, return_type: :Object)
gen.member_binding_as_class_method('main_obj', 'to_s', 'Object', 'main_obj_inspect', argc: 0, pass_env: true, pass_block: false, aliases: ['inspect'], return_type: :Object)

gen.init

puts
puts '}'
