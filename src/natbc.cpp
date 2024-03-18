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

Object *EVAL(Env *env) {
    Value self = GlobalEnv::the()->main_obj();
    volatile bool run_exit_handlers = true;

    // kinda hacky, but needed for top-level begin/rescue
    Args args;
    Block *block = nullptr;

    try {
        // FIXME: top-level `return` in a Ruby script should probably be changed to `exit`.
        // For now, this lambda lets us return a Value from generated code without breaking the C linkage.
        auto result = [&]() -> Value {
            auto hello = new StringObject { "hello world" };
            return self.send(env, "puts"_s, { hello });
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
