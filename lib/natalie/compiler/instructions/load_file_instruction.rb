require_relative './base_instruction'

module Natalie
  class Compiler
    class LoadFileInstruction < BaseInstruction
      def initialize(filename, require_once:)
        super()
        @filename = filename
        @require_once = require_once
      end

      attr_reader :filename

      def to_s
        s = "load_file #{@filename}"
        s << ' (require_once)' if @require_once
        s
      end

      def generate(transform)
        fn = transform.compiled_files[@filename]
        filename_sym = transform.intern(@filename)
        unless fn
          loaded_file = transform.required_ruby_file(@filename)
          fn = build_fn_name(loaded_file)
          transform.compiled_files[@filename] = fn
        end
        transform.top(fn, "Value #{fn}(Env *, Value, bool);")
        transform.exec_and_push(:result_of_load_file, "#{fn}(env, GlobalEnv::the()->main_obj(), #{@require_once})")
      end

      def execute(vm)
        vm.with_self(vm.main) { vm.run }
        :no_halt
      end

      private

      def build_fn_name(loaded_file)
        suffix = loaded_file.relative_path.sub(/^[^a-zA-Z_]/, '_').gsub(/[^a-zA-Z0-9_]/, '_')
        "load_file_fn_#{suffix}"
      end
    end
  end
end
