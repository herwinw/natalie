#include "natalie.hpp"

#include <fstream>
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
            ip = code;
            const auto end = ip + size;
            while (ip < end) {
                const auto operation = *ip++;
                if (debug)
                    printf("%li ", ic++);
                switch (operation) {
                case Instructions::CreateArrayInstruction: {
                    const size_t size = read_ber_integer(&ip);
                    if (debug)
                        printf("create_array %lu\n", size);
                    auto ary = new ArrayObject { size };
                    for (size_t i = 0; i < size; i++)
                        ary->unshift(env, { stack.pop() });
                    stack.push(ary);
                    break;
                }
                case Instructions::CreateHashInstruction: {
                    const size_t size = read_ber_integer(&ip);
                    if (debug)
                        printf("create_hash count: %lu\n", size);
                    Value items[size * 2];
                    for (size_t i = 0; i < size; i++) {
                        items[(size - i) * 2 - 1] = stack.pop();
                        items[(size - i) * 2 - 2] = stack.pop();
                    }
                    stack.push(new HashObject(env, size * 2, items));
                    break;
                }
                case Instructions::PopInstruction:
                    if (debug)
                        printf("pop\n");
                    stack.pop();
                    break;
                case Instructions::PushArgcInstruction: {
                    const size_t size = read_ber_integer(&ip);
                    if (debug)
                        printf("push_argc %lu\n", size);
                    stack.push(Value::integer(static_cast<nat_int_t>(size)));
                    break;
                }
                case Instructions::PushFalseInstruction:
                    if (debug)
                        printf("push_false\n");
                    stack.push(FalseObject::the());
                    break;
                case Instructions::PushFloatInstruction: {
                    static_assert(sizeof(double) == 8);
                    double val;
                    // Convert from network to native byte ordering
                    uint8_t *val_ptr = reinterpret_cast<uint8_t *>(&val);
                    for (size_t i = 0; i < 8; i++)
                        memcpy(val_ptr + 7 - i, ip++, sizeof(uint8_t));
                    stack.push(Value::floatingpoint(val));
                    break;
                }
                case Instructions::PushIntInstruction: {
                    nat_int_t val = *reinterpret_cast<const int8_t *>(ip++);
                    if (val > 5) {
                        val -= 5;
                    } else if (val < -5) {
                        val += 5;
                    } else if (val == 5 || val == -5) {
                        Integer bigval;
                        uint8_t nextval;
                        do {
                            nextval = *ip++;
                            bigval = (bigval << 7) | (nextval & 0x7f);
                        } while (nextval & 0x80);
                        if (val < 0)
                            bigval = -bigval;
                        if (debug)
                            printf("push_int %s\n", bigval.to_string().c_str());
                        stack.push(new IntegerObject { std::move(bigval) });
                        break;
                    } else if (val > 0) { // 1..4
                        const size_t times = val;
                        for (size_t i = 0; i < times; i++) {
                            val |= (*ip++) << (8 * i);
                        }
                    } else if (val < 0) { // -4..-1
                        const size_t times = -val;
                        val = -1;
                        for (size_t i = 0; i < times; i++) {
                            val &= ~(0xff << (8 * i));
                            val |= (*ip++) << (8 * i);
                        }
                    }
                    if (debug)
                        printf("push_int %lli\n", val);
                    stack.push(Value::integer(val));
                    break;
                }
                case Instructions::PushNilInstruction:
                    if (debug)
                        printf("push_nil\n");
                    stack.push(NilObject::the());
                    break;
                case Instructions::PushSelfInstruction:
                    if (debug)
                        printf("push_self\n");
                    stack.push(self);
                    break;
                case Instructions::PushStringInstruction: {
                    if (rodata == nullptr) {
                        std::cerr << "Trying to access rodata section that does not exist\n";
                        exit(1);
                    }
                    const size_t position = read_ber_integer(&ip);
                    const uint8_t *str = rodata + position;
                    const size_t size = read_ber_integer(&str);
                    const auto encoding_position = read_ber_integer(&ip);
                    const uint8_t *encoding_str = rodata + encoding_position;
                    const auto encoding_size = read_ber_integer(&encoding_str);
                    auto encoding = EncodingObject::find(env, new StringObject { reinterpret_cast<const char *>(encoding_str), encoding_size })->as_encoding();

                    auto string = new StringObject { reinterpret_cast<const char *>(str), size, encoding };
                    if (debug)
                        printf("push_string \"%s\", %lu, %s\n", string->c_str(), size, encoding->name()->c_str());
                    stack.push(string);
                    break;
                }
                case Instructions::PushSymbolInstruction: {
                    if (rodata == nullptr) {
                        std::cerr << "Trying to access rodata section that does not exist\n";
                        exit(1);
                    }
                    const size_t position = read_ber_integer(&ip);
                    const uint8_t *str = rodata + position;
                    const size_t size = read_ber_integer(&str);
                    auto symbol = SymbolObject::intern(reinterpret_cast<const char *>(str), size);
                    if (debug)
                        printf("push_symbol :%s\n", symbol->string().c_str());
                    stack.push(symbol);
                    break;
                }
                case Instructions::PushTrueInstruction:
                    if (debug)
                        printf("push_true\n");
                    stack.push(TrueObject::the());
                    break;
                case Instructions::SendInstruction: {
                    if (rodata == nullptr) {
                        std::cerr << "Trying to access rodata section that does not exist\n";
                        exit(1);
                    }
                    const size_t position = read_ber_integer(&ip);
                    const uint8_t *str = rodata + position;
                    const size_t size = read_ber_integer(&str);
                    auto symbol = SymbolObject::intern(reinterpret_cast<const char *>(str), size);
                    const auto flags = *ip++;
                    const bool receiver_is_self = flags & 1;
                    const bool with_block = flags & 2;
                    const bool args_array_on_stack = flags & 4;
                    const bool has_keyword_hash = flags & 8;
                    if (debug) {
                        printf("send :%s", symbol->string().c_str());
                        if (receiver_is_self) printf(" to self");
                        if (with_block) printf(" with block");
                        if (args_array_on_stack) printf(" (args array on stack)");
                        if (has_keyword_hash) printf(" (has keyword hash)");
                        printf("\n");
                    }
                    if (with_block || args_array_on_stack || has_keyword_hash)
                        env->raise("NotImplementedError", "with_block. args_array_on_stack and has_keyword_hash are currently unsupported");
                    TM::Vector<Value> args {};
                    const auto argc = static_cast<size_t>(IntegerObject::convert_to_nat_int_t(env, stack.pop()));
                    for (size_t i = 0; i < argc; i++)
                        args.push_front(stack.pop());
                    auto receiver = stack.pop();
                    if (receiver_is_self) {
                        stack.push(receiver.send(env, symbol, Args(std::move(args))));
                    } else {
                        stack.push(receiver.public_send(env, symbol, Args(std::move(args))));
                    }
                    break;
                }
                default:
                    if (operation < Instructions::_NUM_INSTRUCTIONS) {
                        const auto name = Instructions::Names[operation];
                        env->raise("NotImplementedError", "Unknown instruction: {}", name);
                    } else {
                        env->raise("ScriptError", "Unknown instruction: {}", static_cast<uint64_t>(operation));
                    }
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
