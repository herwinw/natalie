#pragma once

#include <assert.h>
#include <initializer_list>
#include <iterator>

#include "natalie/args.hpp"
#include "natalie/forward.hpp"
#include "natalie/gc/heap.hpp"
#include "natalie/method_visibility.hpp"
#include "natalie/object_type.hpp"
#include "natalie/types.hpp"
#include "tm/optional.hpp"

namespace Natalie {

constexpr unsigned int FALSE_VALUE = 0x0;
constexpr unsigned int NIL_VALUE = 0x4;
constexpr unsigned int TRUE_VALUE = 0x14;

class Value {
public:
    Value()
        : m_value { NIL_VALUE } { }

    Value(std::nullptr_t) = delete;

    Value(Object *object)
        : m_value { reinterpret_cast<uintptr_t>(object) } {
        assert(object != nullptr);
    }

    explicit Value(nat_int_t integer);

    Value(Integer integer);

    static Value integer(nat_int_t integer) {
        // This is required, because initialization by a literal is often ambiguous.
        return Value { integer };
    }

    static Value False() {
        Value v;
        v.m_value = FALSE_VALUE;
        return v;
    }

    static Value nil() {
        Value v;
        v.m_value = NIL_VALUE;
        return v;
    }

    static Value True() {
        Value v;
        v.m_value = TRUE_VALUE;
        return v;
    }

    static Value integer(TM::String &&str);

    Object &operator*() const { return *object(); }
    Object *operator->() const { return object(); }

    Object *object() const {
        assert(!is_integer() && !is_nil() && !is_true() && !is_false());
        return pointer();
    }

    bool operator==(void *ptr) const { return (void *)m_value == ptr; }
    bool operator!=(void *ptr) const { return (void *)m_value != ptr; }

    bool operator==(Value other) const { return m_value == other.m_value; }
    bool operator!=(Value other) const { return m_value != other.m_value; }

    Value public_send(Env *, SymbolObject *, Args &&, Block *, Value sent_from);
    Value public_send(Env *, SymbolObject *, Args && = {}, Block * = nullptr);

    Value public_send(Env *env, SymbolObject *name, std::initializer_list<Value> args, Block *block = nullptr) {
        return public_send(env, name, Args(args), block);
    }

    Value send(Env *, SymbolObject *, Args && = {}, Block * = nullptr);

    Value send(Env *env, SymbolObject *name, std::initializer_list<Value> args, Block *block = nullptr) {
        return send(env, name, Args(args), block);
    }

    Value immediate_send(Env *env, SymbolObject *name, Args &&args, Block *block, MethodVisibility visibility);

    ClassObject *klass() const;

    bool can_have_singleton_class() const { return !is_integer() && !is_float() && !is_symbol(); }
    ClassObject *singleton_class() const;
    ClassObject *singleton_class(Env *);

    // Old error message style, e.g.:
    // - no implicit conversion from nil to string
    // - no implicit conversion of Integer into String
    StringObject *to_str(Env *env);

    // New error message style, e.g.:
    // - no implicit conversion of nil into String
    // - no implicit conversion of Integer into String
    StringObject *to_str2(Env *env);

    Integer integer() const;
    Integer integer_or_raise(Env *) const;

    ObjectType type() const;

    bool is_pointer() const { return m_value != 0x0 && (m_value & 0b111) == 0x0; }
    bool is_fixnum() const { return (m_value & 0x1) == 0x1; }
    bool is_integer() const;
    bool is_nil() const { return m_value == NIL_VALUE; }
    bool is_true() const { return m_value == TRUE_VALUE; }
    bool is_false() const { return m_value == FALSE_VALUE; }
    bool is_frozen() const;

    bool has_heap_object() const { return !is_fixnum() && !is_nil() && !is_true() && !is_false(); }

    bool has_instance_variables() const;

    nat_int_t object_id() const { return (nat_int_t)m_value; }

    void assert_integer(Env *) const;
    void assert_type(Env *, ObjectType, const char *) const;
    void assert_not_frozen(Env *) const;

    bool is_a(Env *, Value) const;
    bool respond_to(Env *, SymbolObject *, bool include_all = true);

    bool is_fiber() const;
    bool is_enumerator_arithmetic_sequence() const;
    bool is_array() const;
    bool is_binding() const;
    bool is_method() const;
    bool is_module() const;
    bool is_class() const;
    bool is_complex() const;
    bool is_dir() const;
    bool is_encoding() const;
    bool is_env() const;
    bool is_exception() const;
    bool is_float() const;
    bool is_hash() const;
    bool is_io() const;
    bool is_file() const;
    bool is_file_stat() const;
    bool is_match_data() const;
    bool is_proc() const;
    bool is_random() const;
    bool is_range() const;
    bool is_rational() const;
    bool is_regexp() const;
    bool is_symbol() const;
    bool is_string() const;
    bool is_thread() const;
    bool is_thread_backtrace_location() const;
    bool is_thread_group() const;
    bool is_thread_mutex() const;
    bool is_time() const;
    bool is_unbound_method() const;
    bool is_void_p() const;

    bool is_truthy() const;
    bool is_falsey() const;
    bool is_numeric() const;
    bool is_boolean() const;

    Enumerator::ArithmeticSequenceObject *as_enumerator_arithmetic_sequence() const;
    ArrayObject *as_array() const;
    BindingObject *as_binding() const;
    ClassObject *as_class() const;
    ComplexObject *as_complex() const;
    DirObject *as_dir() const;
    EncodingObject *as_encoding() const;
    EnvObject *as_env() const;
    ExceptionObject *as_exception() const;
    FiberObject *as_fiber() const;
    FileObject *as_file() const;
    FileStatObject *as_file_stat() const;
    FloatObject *as_float() const;
    HashObject *as_hash() const;
    IoObject *as_io() const;
    MatchDataObject *as_match_data() const;
    MethodObject *as_method() const;
    ModuleObject *as_module() const;
    ProcObject *as_proc() const;
    RandomObject *as_random() const;
    RangeObject *as_range() const;
    RationalObject *as_rational() const;
    RegexpObject *as_regexp() const;
    StringObject *as_string() const;
    SymbolObject *as_symbol() const;
    ThreadObject *as_thread() const;
    Thread::Backtrace::LocationObject *as_thread_backtrace_location() const;
    ThreadGroupObject *as_thread_group() const;
    Thread::MutexObject *as_thread_mutex() const;
    TimeObject *as_time() const;
    UnboundMethodObject *as_unbound_method() const;
    VoidPObject *as_void_p() const;

    ArrayObject *as_array_or_raise(Env *) const;
    ClassObject *as_class_or_raise(Env *) const;
    EncodingObject *as_encoding_or_raise(Env *) const;
    ExceptionObject *as_exception_or_raise(Env *) const;
    FloatObject *as_float_or_raise(Env *) const;
    HashObject *as_hash_or_raise(Env *) const;
    MatchDataObject *as_match_data_or_raise(Env *) const;
    ModuleObject *as_module_or_raise(Env *) const;
    RangeObject *as_range_or_raise(Env *) const;
    StringObject *as_string_or_raise(Env *) const;

    ArrayObject *to_ary(Env *env);
    FloatObject *to_f(Env *env);
    HashObject *to_hash(Env *env);
    IoObject *to_io(Env *env);
    Integer to_int(Env *env);
    StringObject *to_s(Env *env);

    enum class Conversion {
        Strict,
        NullAllowed,
    };

    SymbolObject *to_symbol(Env *, Conversion);

    String inspected(Env *);
    String dbg_inspect(int indent = 0) const;

private:
    friend MarkingVisitor;

    Object *pointer() const {
        return reinterpret_cast<Object *>(m_value);
    }

    __attribute__((no_sanitize("undefined"))) static nat_int_t left_shift_with_undefined_behavior(nat_int_t x, nat_int_t y) {
        return x << y; // NOLINT
    }

    // The least significant bit is used to tag the pointer as either
    // an immediate value (63 bits) or a pointer to an Object.
    // If bit is 1, then shift the value to the right to get the actual
    // 63-bit number. If the bit is 0, then treat the value as a pointer.
    uintptr_t m_value { 0x0 };
};

}
