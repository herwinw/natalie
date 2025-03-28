#pragma once

#include <assert.h>
#include <errno.h>
#include <float.h>
#include <inttypes.h>
#include <signal.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <thread>
#include <unistd.h>
#include <utility>

#include "natalie/args.hpp"
#include "natalie/array_object.hpp"
#include "natalie/backtrace.hpp"
#include "natalie/binding_object.hpp"
#include "natalie/block.hpp"
#include "natalie/class_object.hpp"
#include "natalie/complex_object.hpp"
#include "natalie/constant.hpp"
#include "natalie/dir_object.hpp"

#include "natalie/encoding/ascii_8bit_encoding_object.hpp"
#include "natalie/encoding/eucjp_encoding_object.hpp"
#include "natalie/encoding/ibm037_encoding_object.hpp"
#include "natalie/encoding/ibm437_encoding_object.hpp"
#include "natalie/encoding/ibm720_encoding_object.hpp"
#include "natalie/encoding/ibm737_encoding_object.hpp"
#include "natalie/encoding/ibm775_encoding_object.hpp"
#include "natalie/encoding/ibm850_encoding_object.hpp"
#include "natalie/encoding/ibm852_encoding_object.hpp"
#include "natalie/encoding/ibm855_encoding_object.hpp"
#include "natalie/encoding/ibm857_encoding_object.hpp"
#include "natalie/encoding/ibm860_encoding_object.hpp"
#include "natalie/encoding/ibm861_encoding_object.hpp"
#include "natalie/encoding/ibm862_encoding_object.hpp"
#include "natalie/encoding/ibm863_encoding_object.hpp"
#include "natalie/encoding/ibm864_encoding_object.hpp"
#include "natalie/encoding/ibm865_encoding_object.hpp"
#include "natalie/encoding/ibm866_encoding_object.hpp"
#include "natalie/encoding/ibm869_encoding_object.hpp"
#include "natalie/encoding/iso885910_encoding_object.hpp"
#include "natalie/encoding/iso885911_encoding_object.hpp"
#include "natalie/encoding/iso885913_encoding_object.hpp"
#include "natalie/encoding/iso885914_encoding_object.hpp"
#include "natalie/encoding/iso885915_encoding_object.hpp"
#include "natalie/encoding/iso885916_encoding_object.hpp"
#include "natalie/encoding/iso88591_encoding_object.hpp"
#include "natalie/encoding/iso88592_encoding_object.hpp"
#include "natalie/encoding/iso88593_encoding_object.hpp"
#include "natalie/encoding/iso88594_encoding_object.hpp"
#include "natalie/encoding/iso88595_encoding_object.hpp"
#include "natalie/encoding/iso88596_encoding_object.hpp"
#include "natalie/encoding/iso88597_encoding_object.hpp"
#include "natalie/encoding/iso88598_encoding_object.hpp"
#include "natalie/encoding/iso88599_encoding_object.hpp"
#include "natalie/encoding/koi8r_encoding_object.hpp"
#include "natalie/encoding/koi8u_encoding_object.hpp"
#include "natalie/encoding/shiftjis_encoding_object.hpp"
#include "natalie/encoding/us_ascii_encoding_object.hpp"
#include "natalie/encoding/utf16be_encoding_object.hpp"
#include "natalie/encoding/utf16le_encoding_object.hpp"
#include "natalie/encoding/utf32be_encoding_object.hpp"
#include "natalie/encoding/utf32le_encoding_object.hpp"
#include "natalie/encoding/utf8_encoding_object.hpp"
#include "natalie/encoding/windows1250_encoding_object.hpp"
#include "natalie/encoding/windows1251_encoding_object.hpp"
#include "natalie/encoding/windows1252_encoding_object.hpp"
#include "natalie/encoding/windows1253_encoding_object.hpp"
#include "natalie/encoding/windows1254_encoding_object.hpp"
#include "natalie/encoding/windows1255_encoding_object.hpp"
#include "natalie/encoding/windows1256_encoding_object.hpp"
#include "natalie/encoding/windows1257_encoding_object.hpp"
#include "natalie/encoding/windows1258_encoding_object.hpp"

#include "natalie/encoding_object.hpp"
#include "natalie/enumerator/arithmetic_sequence_object.hpp"
#include "natalie/env.hpp"
#include "natalie/env_object.hpp"
#include "natalie/exception_object.hpp"
#include "natalie/false_methods.hpp"
#include "natalie/fiber_object.hpp"
#include "natalie/file_object.hpp"
#include "natalie/file_stat_object.hpp"
#include "natalie/float_object.hpp"
#include "natalie/forward.hpp"
#include "natalie/gc_module.hpp"
#include "natalie/global_env.hpp"
#include "natalie/hash_builder.hpp"
#include "natalie/hash_object.hpp"
#include "natalie/integer_methods.hpp"
#include "natalie/io_object.hpp"
#include "natalie/kernel_module.hpp"
#include "natalie/local_jump_error_type.hpp"
#include "natalie/match_data_object.hpp"
#include "natalie/method.hpp"
#include "natalie/method_object.hpp"
#include "natalie/module_object.hpp"
#include "natalie/native_profiler.hpp"
#include "natalie/nil_methods.hpp"
#include "natalie/number_parser.hpp"
#include "natalie/object.hpp"
#include "natalie/proc_object.hpp"
#include "natalie/process_module.hpp"
#include "natalie/random_object.hpp"
#include "natalie/range_object.hpp"
#include "natalie/rational_object.hpp"
#include "natalie/regexp_object.hpp"
#include "natalie/signal_module.hpp"
#include "natalie/string_object.hpp"
#include "natalie/string_upto_iterator.hpp"
#include "natalie/symbol_object.hpp"
#include "natalie/thread/backtrace/location_object.hpp"
#include "natalie/thread/mutex_object.hpp"
#include "natalie/thread_group_object.hpp"
#include "natalie/thread_object.hpp"
#include "natalie/time_object.hpp"
#include "natalie/true_methods.hpp"
#include "natalie/types.hpp"
#include "natalie/unbound_method_object.hpp"
#include "natalie/value.hpp"
#include "natalie/void_p_object.hpp"

#ifdef __SANITIZE_ADDRESS__
extern "C" void *__asan_get_current_fake_stack();
extern "C" void *__asan_addr_is_in_fake_stack(void *fake_stack, void *addr, void **beg, void **end);
#endif

namespace Natalie {

extern const char *ruby_platform;
extern const char *ruby_release_date;
extern const char *ruby_revision;

extern "C" {
#include "onigmo.h"
}

enum class FlipFlopState {
    On,
    Transitioning,
    Off,
};

void init_bindings(Env *);

Env *build_top_env();

const char *find_current_method_name(Env *env);

Value splat(Env *env, Value obj);
Value is_case_equal(Env *env, Value case_value, Value when_value, bool is_splat);

void run_at_exit_handlers(Env *env);
void print_exception_with_backtrace(Env *env, ExceptionObject *exception, ThreadObject *thread = nullptr);
void handle_top_level_exception(Env *, ExceptionObject *, bool);

ArrayObject *to_ary(Env *env, Value obj, bool raise_for_non_array);
Value to_ary_for_masgn(Env *env, Value obj);

void arg_spread(Env *env, const Args &args, const char *arrangement, ...);

enum class CoerceInvalidReturnValueMode {
    Raise,
    Allow,
};

std::pair<Value, Value> coerce(Env *, Value, Value, CoerceInvalidReturnValueMode = CoerceInvalidReturnValueMode::Raise);

Block *to_block(Env *, Value);
inline Block *to_block(Env *, Block *block) { return block; }

FILE *popen2(const char *, const char *, pid_t &);
int pclose2(FILE *, pid_t);

void set_status_object(Env *, pid_t, int);

Value super(Env *, Value, Args &&, Block *);

void clean_up_and_exit(int status);

inline Value find_top_level_const(Env *env, SymbolObject *name) {
    return GlobalEnv::the()->Object()->const_find(env, name).value();
}

inline Value fetch_nested_const(std::initializer_list<SymbolObject *> names) {
    Value c = GlobalEnv::the()->Object();
    for (auto name : names)
        c = c.as_module()->const_fetch(name);
    return c;
}

Value bool_object(bool b);

int hex_char_to_decimal_value(char c);

template <typename T>
void dbg(T val) {
    dbg("{v}", val);
}

template <typename... Args>
void dbg(const char *fmt, Args... args) {
    auto out = StringObject::format(fmt, args...);
    puts(out->c_str());
}

int pipe2(int pipefd[2], int flags);

void trap_signal(int signal, void (*handler)(int, siginfo_t *, void *));

void gc_signal_handler(int signal, siginfo_t *, void *ucontext);

void sigint_handler(int, siginfo_t *, void *);
void sigpipe_handler(int, siginfo_t *, void *);

}
