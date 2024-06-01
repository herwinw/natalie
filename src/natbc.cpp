#include "natalie.hpp"

#include <fstream>
#include <functional>
#include <iostream>

#include "generated/instructions.hpp"

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

static size_t read_ber_integer(const uint8_t **p_ip) {
    size_t size = 0;
    const uint8_t *ip = *p_ip;
    uint8_t val;
    do {
        val = *ip++;
        size = (size << 8) | (val & 0x7f);
    } while (val & 0x80);
    *p_ip = ip;
    return size;
}

static size_t read_size_t(const uint8_t **p_ip) {
    size_t size = 0;
    const uint8_t *ip = *p_ip;
    for (size_t i = 0; i < 4; i++)
        size = (size << 8) | *ip++;
    *p_ip = ip;
    return size;
}

struct ctx {
    Env *env;
    TM::Vector<Value> &stack;
    const bool debug;
    const uint8_t *ip;
    const uint8_t *const rodata;
    Value self;
};

using instruction_t = std::function<void(const uint8_t, struct ctx &ctx)>;

void create_array_instruction(const uint8_t, struct ctx &ctx) {
    const size_t size = read_ber_integer(&ctx.ip);
    if (ctx.debug)
        printf("create_array %lu\n", size);
    auto ary = new ArrayObject { size };
    for (size_t i = 0; i < size; i++)
        ary->unshift(ctx.env, { ctx.stack.pop() });
    ctx.stack.push(ary);
}

void create_hash_instruction(const uint8_t, struct ctx &ctx) {
    const size_t size = read_ber_integer(&ctx.ip);
    if (ctx.debug)
        printf("create_hash count: %lu\n", size);
    Value items[size * 2];
    for (size_t i = 0; i < size; i++) {
        items[(size - i) * 2 - 1] = ctx.stack.pop();
        items[(size - i) * 2 - 2] = ctx.stack.pop();
    }
    ctx.stack.push(new HashObject { ctx.env, size * 2, items });
}

void pop_instruction(const uint8_t, struct ctx &ctx) {
    if (ctx.debug)
        printf("pop\n");
    ctx.stack.pop();
}

void push_argc_instruction(const uint8_t, struct ctx &ctx) {
    const size_t size = read_ber_integer(&ctx.ip);
    if (ctx.debug)
        printf("push_argc %lu\n", size);
    ctx.stack.push(Value::integer(static_cast<nat_int_t>(size)));
}

void push_false_instruction(const uint8_t, struct ctx &ctx) {
    if (ctx.debug)
        printf("push_false\n");
    ctx.stack.push(FalseObject::the());
}

void push_float_instruction(const uint8_t, struct ctx &ctx) {
    static_assert(sizeof(double) == 8);
    double val;
    // Convert from network to native byte ordering
    uint8_t *val_ptr = reinterpret_cast<uint8_t *>(&val);
    for (size_t i = 0; i < 8; i++)
        memcpy(val_ptr + 7 - i, ctx.ip++, sizeof(uint8_t));
    ctx.stack.push(Value::floatingpoint(val));
}

void push_int_instruction(const uint8_t, struct ctx &ctx) {
    nat_int_t val = *reinterpret_cast<const int8_t *>(ctx.ip++);
    if (val > 5) {
        val -= 5;
    } else if (val < -5) {
        val += 5;
    } else if (val == 5 || val == -5) {
        Integer bigval;
        uint8_t nextval;
        do {
            nextval = *ctx.ip++;
            bigval = (bigval << 7) | (nextval & 0x7f);
        } while (nextval & 0x80);
        if (val < 0)
            bigval = -bigval;
        if (ctx.debug)
            printf("push_int %s\n", bigval.to_string().c_str());
        ctx.stack.push(new IntegerObject { std::move(bigval) });
        return;
    } else if (val > 0) { // 1..4
        const size_t times = val;
        for (size_t i = 0; i < times; i++) {
            val |= (*ctx.ip++) << (8 * i);
        }
    } else if (val < 0) { // -4..-1
        const size_t times = -val;
        val = -1;
        for (size_t i = 0; i < times; i++) {
            val &= ~(0xff << (8 * i));
            val |= (*ctx.ip++) << (8 * i);
        }
    }
    if (ctx.debug)
        printf("push_int %lli\n", val);
    ctx.stack.push(Value::integer(val));
}

void push_nil_instruction(const uint8_t, struct ctx &ctx) {
    if (ctx.debug)
        printf("push_nil\n");
    ctx.stack.push(NilObject::the());
}

void push_self_instrunction(const uint8_t, struct ctx &ctx) {
    if (ctx.debug)
        printf("push_self\n");
    ctx.stack.push(ctx.self);
}

void push_string_instruction(const uint8_t, struct ctx &ctx) {
    if (ctx.rodata == nullptr) {
        std::cerr << "Trying to access rodata section that does not exist\n";
        exit(1);
    }
    const size_t position = read_ber_integer(&ctx.ip);
    const uint8_t *str = ctx.rodata + position;
    const size_t size = read_ber_integer(&str);
    const auto encoding_position = read_ber_integer(&ctx.ip);
    const uint8_t *encoding_str = ctx.rodata + encoding_position;
    const auto encoding_size = read_ber_integer(&encoding_str);
    auto encoding = EncodingObject::find(ctx.env, new StringObject { reinterpret_cast<const char *>(encoding_str), encoding_size })->as_encoding();
    const bool frozen = *ctx.ip++;

    auto string = new StringObject { reinterpret_cast<const char *>(str), size, encoding };
    if (frozen)
        string->freeze();
    if (ctx.debug)
        printf("push_string \"%s\", %lu, %s%s\n", string->c_str(), size, encoding->name()->c_str(), (frozen ? ", frozen" : ""));
    ctx.stack.push(string);
}

void push_symbol_instruction(const uint8_t, struct ctx &ctx) {
    if (ctx.rodata == nullptr) {
        std::cerr << "Trying to access rodata section that does not exist\n";
        exit(1);
    }
    const size_t position = read_ber_integer(&ctx.ip);
    const uint8_t *str = ctx.rodata + position;
    const size_t size = read_ber_integer(&str);
    auto symbol = SymbolObject::intern(reinterpret_cast<const char *>(str), size);
    if (ctx.debug)
        printf("push_symbol :%s\n", symbol->string().c_str());
    ctx.stack.push(symbol);
}

void send_instruction(const uint8_t, struct ctx &ctx) {
    if (ctx.rodata == nullptr) {
        std::cerr << "Trying to access rodata section that does not exist\n";
        exit(1);
    }
    const size_t position = read_ber_integer(&ctx.ip);
    const uint8_t *str = ctx.rodata + position;
    const size_t size = read_ber_integer(&str);
    auto symbol = SymbolObject::intern(reinterpret_cast<const char *>(str), size);
    const auto flags = *ctx.ip++;
    const bool receiver_is_self = flags & 1;
    const bool with_block = flags & 2;
    const bool args_array_on_stack = flags & 4;
    const bool has_keyword_hash = flags & 8;
    if (ctx.debug) {
        printf("send :%s", symbol->string().c_str());
        if (receiver_is_self) printf(" to self");
        if (with_block) printf(" with block");
        if (args_array_on_stack) printf(" (args array on stack)");
        if (has_keyword_hash) printf(" (has keyword hash)");
        printf("\n");
    }
    if (args_array_on_stack || has_keyword_hash)
        ctx.env->raise("NotImplementedError", "with_block. args_array_on_stack and has_keyword_hash are currently unsupported");
    TM::Vector<Value> args {};
    const auto argc = static_cast<size_t>(IntegerObject::convert_to_nat_int_t(ctx.env, ctx.stack.pop()));
    for (size_t i = 0; i < argc; i++)
        args.push_front(ctx.stack.pop());
    auto receiver = ctx.stack.pop();
    Block *block = nullptr;
    if (with_block) {
        auto proc = ctx.stack.pop();
        if (!proc->is_symbol())
            ctx.env->raise("ScriptError", "Expected Symbol object, got {} instead", proc->inspect_str(ctx.env));
        block = to_block(ctx.env, proc);
    }
    if (receiver_is_self) {
        ctx.stack.push(receiver.send(ctx.env, symbol, Args(std::move(args)), block));
    } else {
        ctx.stack.push(receiver.public_send(ctx.env, symbol, Args(std::move(args)), block));
    }
}

void push_true_instruction(const uint8_t, struct ctx &ctx) {
    if (ctx.debug)
        printf("push_true\n");
    ctx.stack.push(TrueObject::the());
}

void unimplemented_instruction(const uint8_t operation, struct ctx &ctx) {
    const auto name = Instructions::Names[operation];
    ctx.env->raise("NotImplementedError", "Unknown instruction: {}", name);
}

static const auto instruction_handler = []() {
    TM::Vector<instruction_t> instruction_handler { static_cast<size_t>(Instructions::_NUM_INSTRUCTIONS), unimplemented_instruction };
    instruction_handler[static_cast<size_t>(Instructions::CreateArrayInstruction)] = create_array_instruction;
    instruction_handler[static_cast<size_t>(Instructions::CreateHashInstruction)] = create_hash_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PopInstruction)] = pop_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushArgcInstruction)] = push_argc_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushFalseInstruction)] = push_false_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushFloatInstruction)] = push_float_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushIntInstruction)] = push_int_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushNilInstruction)] = push_nil_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushSelfInstruction)] = push_self_instrunction;
    instruction_handler[static_cast<size_t>(Instructions::PushStringInstruction)] = push_string_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushSymbolInstruction)] = push_symbol_instruction;
    instruction_handler[static_cast<size_t>(Instructions::PushTrueInstruction)] = push_true_instruction;
    instruction_handler[static_cast<size_t>(Instructions::SendInstruction)] = send_instruction;
    return instruction_handler;
}();

Object *EVAL(Env *env, const TM::String &bytecode, const bool debug) {
    Value self = GlobalEnv::the()->main_obj();
    volatile bool run_exit_handlers = true;

    // kinda hacky, but needed for top-level begin/rescue
    Args args;
    Block *block = nullptr;

    // NATFIXME: Randomly chosen initialize size, should be enough for now. It prevents a few reallocs
    TM::Vector<Value> stack { 25 };

    auto ip = reinterpret_cast<const uint8_t *>(bytecode.c_str()); // Instruction pointer
    size_t ic = 0; // Instruction counter

    try {
        if (strncmp(reinterpret_cast<const char *>(ip), "NatX", 4))
            env->raise("RuntimeError", "Invalid header, this is probably not a Natalie bytecode file");
        ip += 4;
        const uint8_t major_version = *ip++;
        const uint8_t minor_version = *ip++;
        if (major_version != 0 || minor_version != 0)
            env->raise("RuntimeError", "Invalid version, expected 0.0, got {}.{}", static_cast<int>(major_version), static_cast<int>(minor_version));

        const size_t num_sections = *ip++;
        const uint8_t *rodata = nullptr;
        const uint8_t *code = nullptr;
        for (size_t i = 0; i < num_sections; i++) {
            constexpr size_t header_size = 5;
            const uint8_t type = *ip++;
            const uint32_t offset = read_size_t(&ip);
            switch (type) {
            case 1:
                code = reinterpret_cast<const uint8_t *>(bytecode.c_str()) + header_size + offset;
                break;
            case 2:
                rodata = reinterpret_cast<const uint8_t *>(bytecode.c_str()) + header_size + offset;
                rodata += sizeof(offset); // Skip length for now
                break;
            default:
                env->raise("RuntimeError", "Unable to read sections");
            }
        }

        // FIXME: top-level `return` in a Ruby script should probably be changed to `exit`.
        // For now, this lambda lets us return a Value from generated code without breaking the C linkage.
        auto result = [&]() -> Value {
            const uint32_t size = read_size_t(&code);
            struct ctx ctx {
                env, stack, debug, code, rodata, self
            };
            const auto end = ctx.ip + size;
            while (ctx.ip < end) {
                const auto operation = *ctx.ip++;
                if (debug)
                    printf("%li ", ic++);
                if (operation < Instructions::_NUM_INSTRUCTIONS) {
                    instruction_handler[static_cast<size_t>(operation)](operation, ctx);
                } else {
                    env->raise("ScriptError", "Unknown instruction: {}", static_cast<uint64_t>(operation));
                }
                if (debug) {
                    printf("Stack:\n");
                    for (auto v : stack)
                        printf("\t%s\n", v->inspect_str(env).c_str());
                    printf("\n");
                }
            }
            if (stack.is_empty())
                return NilObject::the();
            return stack.pop();
        }();
        run_exit_handlers = false;
        run_at_exit_handlers(env);
        return result.object();
    } catch (ExceptionObject *exception) {
        handle_top_level_exception(env, exception, run_exit_handlers);
        return nullptr;
    }
}

int main(int argc, const char *argv[]) {
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
    const char *filename = argv[0];
    bool debug = false;
    if (argc > 0 && strcmp("--debug-bytecode", argv[1]) == 0) {
        debug = true;
        argv++;
        argc--;
    }
    if (argc == 1) {
        std::cerr << "Please use " << filename << " [--debug-bytecode] <filename> [args]\n";
        exit(1);
    }
    std::ifstream file;
    file.open(argv[1], std::ios::binary);
    if (!file.is_open()) {
        std::cerr << "Please use " << filename << " [--debug-bytecode] <filename> [args]\n";
        exit(1);
    }
    file.seekg(0, std::ios::end);
    const auto size = file.tellg();
    TM::String bytecode { static_cast<size_t>(size), '\0' };
    file.seekg(0, std::ios::beg);
    file.read(&bytecode[0], size);
    file.close();

    for (int i = 2; i < argc; i++) {
        ARGV->push(new StringObject { argv[i] });
    }

    auto result = EVAL(env, bytecode, debug);
    auto return_code = result ? 0 : 1;

    clean_up_and_exit(return_code);
}
