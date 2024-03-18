#include "natalie.hpp"

using namespace Natalie;

// NATFIXME: Disable GC for now, since we only run trivial programs and save
//           values on an unchecked stack.
#define NAT_GC_DISABLE

Value init_exception(Env *env, Value self);
Value init_array(Env *env, Value self);
Value init_comparable(Env *env, Value self);
Value init_complex(Env *env, Value self);
Value init_data(Env *env, Value self);
Value init_dir(Env *env, Value self);
Value init_encoding_converter(Env *env, Value self);
Value init_enumerable(Env *env, Value self);
Value init_enumerator(Env *env, Value self);
Value init_errno(Env *env, Value self);
Value init_file(Env *env, Value self);
Value init_hash(Env *env, Value self);
Value init_integer(Env *env, Value self);
Value init_io(Env *env, Value self);
Value init_kernel(Env *env, Value self);
Value init_marshal(Env *env, Value self);
Value init_math(Env *env, Value self);
Value init_numeric(Env *env, Value self);
Value init_proc(Env *env, Value self);
Value init_process(Env *env, Value self);
Value init_random(Env *env, Value self);
Value init_range(Env *env, Value self);
Value init_rbconfig(Env *env, Value self);
Value init_string(Env *env, Value self);
Value init_struct(Env *env, Value self);
Value init_thread_conditionvariable(Env *env, Value self);
Value init_thread_queue(Env *env, Value self);
Value init_time(Env *env, Value self);
Value init_warning(Env *env, Value self);

Env *build_top_env() {
    auto env = Natalie::build_top_env();
    Value self = GlobalEnv::the()->main_obj();
    init_exception(env, self);
    init_array(env, self);
    init_comparable(env, self);
    init_complex(env, self);
    init_data(env, self);
    init_dir(env, self);
    init_encoding_converter(env, self);
    init_enumerable(env, self);
    init_enumerator(env, self);
    init_errno(env, self);
    init_file(env, self);
    init_hash(env, self);
    init_integer(env, self);
    init_io(env, self);
    init_kernel(env, self);
    init_marshal(env, self);
    init_math(env, self);
    init_numeric(env, self);
    init_proc(env, self);
    init_process(env, self);
    init_random(env, self);
    init_range(env, self);
    init_rbconfig(env, self);
    init_string(env, self);
    init_struct(env, self);
    init_thread_conditionvariable(env, self);
    init_thread_queue(env, self);
    init_time(env, self);
    init_warning(env, self);
    return env;
}

static size_t read_ber_integer(const char **p_ip) {
    size_t size = 0;
    const char *ip = *p_ip;
    do {
        size = (size << 8) | (*ip++ & 0x7f);
    } while (*ip & 0x80);
    *p_ip = ip;
    return size;
}

Object *EVAL(Env *env) {
    Value self = GlobalEnv::the()->main_obj();
    volatile bool run_exit_handlers = true;

    // kinda hacky, but needed for top-level begin/rescue
    Args args;
    Block *block = nullptr;

    // NATFIXME: For now, hardcode the bytecode for examples/hello.rb. This should be read from a file eventually
    TM::String bytecode { "\x48\x49\x0b\x68\x65\x6c\x6c\x6f\x20\x77\x6f\x72\x6c\x64\x3a\x01\x4f\x04\x70\x75\x74\x73\x01", 23 };
    auto ip = bytecode.c_str(); // Instruction pointer
    size_t ic = 0; // Instruction counter

    try {
        // FIXME: top-level `return` in a Ruby script should probably be changed to `exit`.
        // For now, this lambda lets us return a Value from generated code without breaking the C linkage.
        auto result = [&]() -> Value {
            while (ip < bytecode.c_str() + bytecode.size()) {
                const auto operation = *ip++;
                printf("%li ", ic++);
                switch (operation) {
                case 0x3a: { // push_argc
                    const size_t size = read_ber_integer(&ip);
                    printf("push_argc %lu\n", size);
                    break;
                }
                case 0x48: // push_self
                    printf("push_self\n");
                    break;
                case 0x49: { // push_string
                    const size_t size = read_ber_integer(&ip);
                    auto string = new StringObject { ip, size };
                    ip += size;
                    // NATFIXME: We probably have to add the encoding to the bytecode as well
                    printf("push_string \"%s\", %lu, %s\n", string->c_str(), size, "UTF-8");
                    break;
                }
                case 0x4f: { // send
                    const size_t size = read_ber_integer(&ip);
                    auto symbol = SymbolObject::intern(ip, size);
                    ip += size;
                    const auto flags = *ip++;
                    const bool receiver_is_self = flags & 1;
                    const bool with_block = flags & 2;
                    const bool args_array_on_stack = flags & 4;
                    const bool has_keyword_hash = flags & 8;
                    printf("send :%s", symbol->string().c_str());
                    if (receiver_is_self) printf(" to self");
                    if (with_block) printf(" with block");
                    if (args_array_on_stack) printf(" (args array on stack)");
                    if (has_keyword_hash) printf(" (has keyword hash)");
                    printf("\n");
                    break;
                }
                default:
                    env->raise("NotImplementedError", "Unknown instruction: {}", static_cast<uint64_t>(operation));
                }
            }
            return NilObject::the();
        }();
        run_exit_handlers = false;
        run_at_exit_handlers(env);
        return result.object();
    } catch (ExceptionObject *exception) {
        handle_top_level_exception(env, exception, run_exit_handlers);
        return nullptr;
    }
}

int main(int argc, char *argv[]) {
    setvbuf(stdout, nullptr, _IOLBF, 1024);

    Env *env = ::build_top_env();
    ThreadObject::build_main_thread(env, __builtin_frame_address(0));

    trap_signal(SIGINT, sigint_handler);
    trap_signal(SIGPIPE, sigpipe_handler);
#if !defined(__APPLE__)
    trap_signal(SIGUSR1, gc_signal_handler);
    trap_signal(SIGUSR2, gc_signal_handler);
#endif

    if (argc > 0) {
        Value exe = new StringObject { argv[0] };
        env->global_set("$exe"_s, exe);
    }

    ArrayObject *ARGV = new ArrayObject { (size_t)argc };
    GlobalEnv::the()->Object()->const_set("ARGV"_s, ARGV);
    for (int i = 1; i < argc; i++) {
        ARGV->push(new StringObject { argv[i] });
    }

    auto result = EVAL(env);
    auto return_code = result ? 0 : 1;

    clean_up_and_exit(return_code);
}
