module Natalie
  class Compiler
    class CppBackend
      class Transform
        def initialize(instructions, compiler_context:, transform_data:, stack: [], compiled_files: {})
          if instructions.is_a?(InstructionManager)
            @instructions = instructions
          else
            @instructions = InstructionManager.new(instructions)
          end
          @result_stack = []
          @code = []
          @compiler_context = compiler_context
          @stack = stack
          @compiled_files = compiled_files
          @transform_data = transform_data
          @top = transform_data.top
          @symbols = transform_data.symbols
          @interned_strings = transform_data.interned_strings
          @inline_functions = transform_data.inline_functions
          @var_prefix = transform_data.var_prefix
        end

        def ip
          @instructions.ip
        end

        attr_reader :stack, :env, :compiled_files

        attr_accessor :inline_functions

        def transform(result_prefix = nil)
          @instructions.walk do |instruction|
            @env = instruction.env
            instruction.generate(self)
            @file = nil if instruction.is_a?(LoadFileInstruction)
          end
          @code << @stack.pop
          stringify_code(@code, result_prefix)
        end

        def semicolon(line)
          line.strip =~ /^\#|[{};]$/ ? line : "#{line};"
        end

        def exec(code)
          @code << stringify_code(code)
        end

        def exec_and_push(name, code, type: 'Value')
          result = memoize(name, code, type:)
          push(result)
          result
        end

        def memoize(name, code, type: 'Value')
          result = temp(name)
          @code << stringify_code(code, "#{type} #{result} =")
          result
        end

        def push(result)
          @stack << result
        end

        def push_nil
          @stack << 'Value::nil()'
        end

        def pop
          raise 'ran out of stack' unless @stack.any?

          @stack.pop
        end

        def peek
          raise 'ran out of stack' unless @stack.any?

          @stack.last
        end

        def find_var(name, local_only: false)
          env = @env
          depth = 0

          loop do
            env = env.fetch(:outer) while env[:hoist]
            if env.fetch(:vars).key?(name)
              var = env.dig(:vars, name)
              return depth, var
            end
            if env.fetch(:type) == :define_block && !local_only && (outer = env.fetch(:outer))
              env = outer
              depth += 1
            else
              break
            end
          end

          raise "unknown variable #{name}"
        end

        def fetch_block_of_instructions(until_instruction: EndInstruction, expected_label: nil)
          @instructions.fetch_block(until_instruction: until_instruction, expected_label: expected_label)
        end

        def temp(name)
          name = name.to_s.gsub(/[^a-zA-Z_]/, '')
          n = @transform_data.next_var_num
          "#{@var_prefix}#{name}#{n}"
        end

        def with_new_scope(instructions)
          t =
            Transform.new(
              instructions,
              transform_data: @transform_data,
              compiler_context: @compiler_context,
              compiled_files: @compiled_files,
            )
          yield(t)
        end

        def with_same_scope(instructions)
          stack = @stack.dup
          t =
            Transform.new(
              instructions,
              stack: stack,
              transform_data: @transform_data,
              compiler_context: @compiler_context,
              compiled_files: @compiled_files,
            )
          yield(t)
          @stack_sizes << stack.size if @stack_sizes
          stack.size
        end

        # truncate resulting stack to minimum size of any
        # code branch within this block
        def normalize_stack
          @stack_sizes = []
          yield
          @stack[@stack_sizes.min..] = []
          @stack_sizes = nil
        end

        def get_top = @top

        def top(name, code)
          @top[name] = Array(code).join("\n")
        end

        def intern(symbol)
          index = @symbols[symbol] ||= @symbols.size
          comment = "/*:#{symbol.to_s.gsub(%r{\*/|\\}, '?')}*/"
          "#{symbols_var_name}[#{index}]#{comment}"
        end

        def interned_string(str, encoding)
          index = @interned_strings[[str, encoding]] ||= @interned_strings.size
          "#{interned_strings_var_name}[#{index}]/*#{str.inspect.gsub(%r{/\*|\*/|\\}, '?')}*/"
        end

        def set_file(file)
          return unless file && file != @file
          @file = file
          exec("env->set_file(#{@file.inspect})")
        end

        def set_line(line)
          return unless line && line != @line
          @line = line
          exec("env->set_line(#{@line})")
        end

        def add_cxx_flags(flags)
          @compiler_context[:compile_cxx_flags] << flags
        end

        def add_ld_flags(flags)
          @compiler_context[:compile_ld_flags] << flags
        end

        def required_ruby_file(filename)
          @compiler_context[:required_ruby_files].fetch(filename)
        end

        def inspect
          "<#{self.class.name}:0x#{object_id.to_s(16)}>"
        end

        def has_file(name)
          "GlobalEnv::the()->has_file(#{name})"
        end

        def add_file(name)
          "GlobalEnv::the()->add_file(env, #{name})"
        end

        private

        def value_has_side_effects?(value)
          return false if value =~ /^Value\((False|Nil|True)Object::the\(\)\)$/
          return false if value =~ %r{^Value\(\w*symbols\[\d+\]/\*\:[^\*]+\*/\)$}
          true
        end

        def symbols_var_name
          "#{@var_prefix}symbols"
        end

        def interned_strings_var_name
          "#{@var_prefix}interned_strings"
        end

        def stringify_code(lines, result_prefix = nil)
          lines = Array(lines).compact
          out = []
          while lines.any?
            line = lines.shift
            next if line.nil?
            next if result_prefix.nil? && !value_has_side_effects?(line)
            if lines.empty? && line !~ /^\s*env->raise|^\s*break;?$/
              out << "#{result_prefix} #{semicolon(line)}"
            else
              out << semicolon(line)
            end
          end
          out.join("\n")
        end
      end
    end
  end
end
