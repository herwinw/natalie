require_relative './cpp_backend/transform'
require_relative '../string_to_cpp'
require_relative '../flags'

module Natalie
  class Compiler
    class CppBackend
      include StringToCpp
      include Flags

      ROOT_DIR = File.expand_path('../../../../', __dir__)
      BUILD_DIR = File.join(ROOT_DIR, 'build')
      SRC_PATH = File.join(ROOT_DIR, 'src')
      MAIN_TEMPLATE = File.read(File.join(SRC_PATH, 'main.cpp'))
      OBJ_TEMPLATE = File.read(File.join(SRC_PATH, 'obj_unit.cpp'))

      DARWIN = RUBY_PLATFORM.match?(/darwin/)
      OPENBSD = RUBY_PLATFORM.match?(/openbsd/)

      DL_EXT = RbConfig::CONFIG['DLEXT']

      INC_PATHS = [
        File.join(ROOT_DIR, 'include'),
        File.join(ROOT_DIR, 'ext/tm/include'),
        File.join(BUILD_DIR),
        File.join(BUILD_DIR, 'onigmo/include'),
      ].freeze

      # When running `bin/natalie script.rb`, we use dynamic linking to speed things up.
      LIBRARIES_FOR_DYNAMIC_LINKING = %w[
        -lnatalie_base
        -lonigmo
      ].freeze

      # When compiling a binary with the `-c` option, we use static linking for compatibility.
      LIBRARIES_FOR_STATIC_LINKING = %w[
        -lnatalie
      ].freeze

      LIB_PATHS = [
        BUILD_DIR,
        File.join(BUILD_DIR, 'onigmo/lib'),
        File.join(BUILD_DIR, 'zlib'),
        File.join(BUILD_DIR, 'json-c'),
      ].freeze

      PACKAGES_REQUIRING_PKG_CONFIG = %w[openssl libffi yaml-0.1].freeze

      def initialize(instructions, compiler:, compiler_context:)
        @instructions = instructions
        @compiler = compiler
        @compiler_context = compiler_context
        augment_compiler_context
        @symbols = {}
        @interned_strings = {}
        @inline_functions = {}
        @top = []
      end

      attr_reader :cpp_path

      def compile_to_binary
        prepare_temp
        compile_temp_to_binary
      end

      def prepare_temp
        check_build
        write_file
      end

      def compile_temp_to_binary
        cmd = compiler_command
        out = `#{cmd} 2>&1`
        File.unlink(@cpp_path) unless @compiler.keep_cpp? || $? != 0
        puts "cpp file path is: #{@cpp_path}" if @compiler.keep_cpp?
        warn out if out.strip != ''
        raise Compiler::CompileError, 'There was an error compiling.' if $? != 0
      end

      def compile_to_object
        cpp = generate
        File.write(@compiler.write_obj_path, cpp)
      end

      def compiler_command
        [
          cc,
          build_flags,
          (@compiler.repl? ? LIBNAT_AND_REPL_FLAGS.join(' ') : ''),
          inc_paths.map { |path| "-I #{path}" }.join(' '),
          "-o #{@compiler.out_path}",
          '-x c++ -std=c++17',
          (cpp_path || 'code.cpp'),
          lib_paths.map { |path| "-L #{path}" }.join(' '),
          libraries.join(' '),
          link_flags,
        ].map(&:to_s).join(' ')
      end

      def write_file_for_debugging
        write_file
        @cpp_path
      end

      private

      def write_file
        cpp = generate
        temp_cpp = Tempfile.create('natalie.cpp')
        temp_cpp.write(cpp)
        temp_cpp.close
        @cpp_path = temp_cpp.path
      end

      def check_build
        return if File.file?(File.join(BUILD_DIR, "libnatalie_base.#{DL_EXT}"))

        puts 'please run: rake'
        exit 1
      end

      def generate
        string_of_cpp = transform_instructions
        out = merge_cpp_with_template(string_of_cpp)
        reindent(out)
      end

      def transform_instructions
        transform = Transform.new(
          @instructions,
          top:              @top,
          compiler_context: @compiler_context,
          symbols:          @symbols,
          interned_strings: @interned_strings,
          inline_functions: @inline_functions,
        )
        transform.transform('return')
      end

      def merge_cpp_with_template(string_of_cpp)
        template
          .sub('/*' + 'NAT_DECLARATIONS' + '*/') { declarations }
          .sub('/*' + 'NAT_OBJ_INIT' + '*/') { init_object_files.join("\n") }
          .sub('/*' + 'NAT_EVAL_INIT' + '*/') { init_matter }
          .sub('/*' + 'NAT_EVAL_BODY' + '*/') { string_of_cpp }
      end

      def template
        if write_object_file?
          OBJ_TEMPLATE.gsub(/OBJ_NAME/, obj_name)
        else
          MAIN_TEMPLATE
        end
      end

      def libraries
        if @compiler.repl?
          []
        elsif @compiler.dynamic_linking?
          LIBRARIES_FOR_DYNAMIC_LINKING
        else
          LIBRARIES_FOR_STATIC_LINKING
        end
      end

      def obj_name
        @compiler
          .write_obj_path
          .sub(/\.rb\.cpp/, '')
          .sub(%r{.*build/(generated/)?}, '')
          .tr('/', '_')
      end

      def var_prefix
        if write_object_file?
          "#{obj_name}_"
        elsif @compiler.repl?
          "repl#{@compiler.repl_num}_"
        else
          ''
        end
      end

      def cc
        ENV['CXX'] || 'c++'
      end

      def inc_paths
        INC_PATHS +
          PACKAGES_REQUIRING_PKG_CONFIG.flat_map do |package|
            flags_for_package(package, :inc)
          end.compact
      end

      def lib_paths
        LIB_PATHS +
          PACKAGES_REQUIRING_PKG_CONFIG.flat_map do |package|
            flags_for_package(package, :lib)
          end.compact
      end

      # FIXME: We should run this on any system (not just Darwin), but only when one
      # of the packages in PACKAGES_REQUIRING_PKG_CONFIG are used.
      def flags_for_package(package, type)
        return unless DARWIN

        @flags_for_package ||= {}
        existing_flags = @flags_for_package[package]
        return existing_flags[type] if existing_flags

        unless system("pkg-config --exists #{package}")
          @flags_for_package[package] = { inc: [], lib: [] }
          return []
        end

        flags = @flags_for_package[package] = {}
        unless (inc_result = `pkg-config --cflags #{package}`.strip).empty?
          flags[:inc] = inc_result.sub(/^-I/, '')
        end
        unless (lib_result = `pkg-config --libs-only-L #{package}`.strip).empty?
          flags[:lib] = lib_result.sub(/^-L/, '')
        end

        flags[type]
      end

      def link_flags
        flags = if @compiler.build == 'sanitized'
                  [SANITIZE_FLAG]
                else
                  []
                end
        flags += @compiler_context[:compile_ld_flags].join(' ').split
        flags -= unnecessary_link_flags
        flags.join(' ')
      end

      def build_flags
        (
          base_build_flags +
          [ENV['NAT_CXX_FLAGS']].compact +
          @compiler_context[:compile_cxx_flags]
        ).join(' ')
      end

      def base_build_flags
        case @compiler.build
        when 'release'
          RELEASE_FLAGS
        when 'debug', nil
          DEBUG_FLAGS
        when 'sanitized'
          SANITIZED_FLAGS
        when 'coverage'
          COVERAGE_FLAGS
        else
          raise "unknown build mode: #{@compiler.build.inspect}"
        end
      end

      def unnecessary_link_flags
        OPENBSD ? ['-ldl'] : []
      end

      def write_object_file?
        !!@compiler.write_obj_path
      end

      def declarations
        [
          object_file_declarations,
          symbols_declaration,
          interned_strings_declaration,
          @top.join("\n")
        ].join("\n\n")
      end

      def init_matter
        [
          init_symbols.join("\n"),
          init_interned_strings.join("\n"),
          init_dollar_zero_global,
        ].compact.join("\n\n")
      end

      def object_file_declarations
        object_files.map { |name| "Value init_#{name.tr('/', '_')}(Env *env, Value self);" }.join("\n")
      end

      def symbols_declaration
        "static SymbolObject *#{symbols_var_name}[#{@symbols.size}] = {};"
      end

      def interned_strings_declaration
        return '' if @interned_strings.empty?

        "static StringObject *#{interned_strings_var_name}[#{@interned_strings.size}] = { 0 };"
      end

      def init_object_files
        object_files.map do |name|
          "init_#{name.tr('/', '_')}(env, self);"
        end
      end

      def init_symbols
        @symbols.map do |name, index|
          "#{symbols_var_name}[#{index}] = SymbolObject::intern(#{string_to_cpp(name.to_s)}, #{name.to_s.bytesize});"
        end
      end

      def init_interned_strings
        return [] if @interned_strings.empty?

        # Start with setting the interned strings list all to nullptr and register the GC hook before creating strings
        # Otherwise, we might start GC before we finished setting up this structure if the source contains enough strings
        [
          "GlobalEnv::the()->set_interned_strings(#{interned_strings_var_name}, #{@interned_strings.size});"
        ] + @interned_strings.flat_map do |(str, encoding), index|
          enum = encoding.name.tr('-', '_').upcase
          encoding_object = "EncodingObject::get(Encoding::#{enum})"
          new_string = if str.empty?
                         "#{interned_strings_var_name}[#{index}] = new StringObject(#{encoding_object});"
                       else
                         "#{interned_strings_var_name}[#{index}] = new StringObject(#{string_to_cpp(str)}, #{str.bytesize}, #{encoding_object});"
                       end
          [
            new_string,
            "#{interned_strings_var_name}[#{index}]->freeze();",
          ]
        end
      end

      def init_dollar_zero_global
        return if write_object_file?

        "env->global_set(\"$0\"_s, new StringObject { #{@compiler_context[:source_path].inspect} });"
      end

      def symbols_var_name
        static_var_name('symbols')
      end

      def interned_strings_var_name
        static_var_name('interned_strings')
      end

      def static_var_name(suffix)
        "#{@compiler_context[:var_prefix]}#{suffix}"
      end

      def object_files
        rb_files = Dir[File.expand_path('../../../../src/**/*.rb', __dir__)].map do |path|
          path.sub(%r{^.*/src/}, '')
        end.grep(%r{^([a-z0-9_]+/)?[a-z0-9_]+\.rb$})
        list = rb_files.sort.map { |name| name.split('.').first }
        ['exception'] + # must come first
          (list - ['exception']) +
          @compiler_context[:required_cpp_files].values
      end

      def reindent(code)
        out = []
        indent = 0
        code
          .split("\n")
          .each do |line|
            indent -= 4 if line =~ /^\s*\}/
            indent = [0, indent].max
            if line.start_with?('#')
              out << line
            else
              out << line.sub(/^\s*/, ' ' * indent)
            end
            indent += 4 if line.end_with?('{')
          end
        out.join("\n")
      end

      def augment_compiler_context
        @compiler_context.merge!(
          compile_cxx_flags: [],
          compile_ld_flags:  [],
          var_prefix:        var_prefix,
        )
      end
    end
  end
end
