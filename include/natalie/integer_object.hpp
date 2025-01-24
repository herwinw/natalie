#pragma once

#include "natalie/bigint.hpp"
#include <assert.h>
#include <inttypes.h>

#include "natalie/class_object.hpp"
#include "natalie/constants.hpp"
#include "natalie/forward.hpp"
#include "natalie/global_env.hpp"
#include "natalie/integer.hpp"
#include "natalie/macros.hpp"
#include "natalie/object.hpp"
#include "natalie/rounding_mode.hpp"
#include "natalie/types.hpp"
#include "nathelpers/typeinfo.hpp"

namespace Natalie {

class IntegerObject : public Object {
public:
    IntegerObject(const nat_int_t integer)
        : Object { Object::Type::Integer, GlobalEnv::the()->Integer() }
        , m_integer { integer } { }

    IntegerObject(const Integer &integer)
        : Object { Object::Type::Integer, GlobalEnv::the()->Integer() }
        , m_integer { integer } { }

    IntegerObject(Integer &&integer)
        : Object { Object::Type::Integer, GlobalEnv::the()->Integer() }
        , m_integer { std::move(integer) } { }

    static Value create(nat_int_t);
    static Value create(const Integer &);
    static Value create(Integer &&);
    static Value create(const char *);
    static Value create(const TM::String &);
    static Value create(TM::String &&);

    static Integer &integer(IntegerObject *self) {
        return self->m_integer;
    }

    static bool is_negative(const IntegerObject *self) { return self->m_integer.is_negative(); }
    static bool is_negative(const Integer self) { return self.is_negative(); }

    static bool is_zero(const IntegerObject *self) { return is_zero(self->m_integer); }
    static bool is_zero(const Integer self) { return self == 0; }

    static bool is_odd(const IntegerObject *self) { return is_odd(self->m_integer); }
    static bool is_odd(const Integer self) { return self % 2 != 0; }

    static bool is_even(const IntegerObject *self) { return !is_odd(self); }
    static bool is_even(const Integer self) { return !is_odd(self); }

    static Value from_size_t(Env *env, size_t number) {
        assert(number <= NAT_INT_MAX);
        return Value::integer(static_cast<nat_int_t>(number));
    }

    static Value from_ssize_t(Env *env, ssize_t number) {
        assert(number <= NAT_INT_MAX && number >= NAT_INT_MIN);
        return Value::integer(static_cast<nat_int_t>(number));
    }

    static nat_int_t convert_to_nat_int_t(Env *, Value);
    static int convert_to_int(Env *, Value);
    static uid_t convert_to_uid(Env *, Value);
    static gid_t convert_to_gid(Env *, Value);

    template <class T>
    static T convert_to_native_type(Env *env, Value arg) {
        auto integer = Object::to_int(env, arg);
        if (is_bignum(integer))
            env->raise("RangeError", "bignum too big to convert into '{}'", typeinfo<T>().name());
        const auto result = integer.to_nat_int_t();
        if (!std::numeric_limits<T>::is_signed && result < 0)
            env->raise("ArgumentError", "negative length {} given", result);
        if (result < static_cast<nat_int_t>(std::numeric_limits<T>::min()))
            env->raise("RangeError", "integer {} too small to convert to '{}'", result, typeinfo<T>().name());
        if (((std::numeric_limits<T>::is_signed && result > 0) || !std::numeric_limits<T>::is_signed) && static_cast<unsigned long long>(result) > std::numeric_limits<T>::max())
            env->raise("RangeError", "integer {} too big to convert to '{}'", result, typeinfo<T>().name());
        return static_cast<T>(result);
    }

    static Value sqrt(Env *, Value);

    static Value inspect(Env *env, IntegerObject *self) { return to_s(env, self); }
    static Value inspect(Env *env, Integer &self) { return to_s(env, self); }

    static String to_s(const IntegerObject *self) { return self->m_integer.to_string(); }
    static String to_s(const Integer &self) { return self.to_string(); }

    static Value to_s(Env *, IntegerObject *, Value = nullptr);
    static Value to_s(Env *env, Integer &self, Value base = nullptr) { return to_s(env, new IntegerObject(self), base); }
    static Value to_i(IntegerObject *);
    static Value to_i(Integer &self) { return to_i(new IntegerObject(self)); }
    static Value to_f(IntegerObject *);
    static Value to_f(Integer &self) { return to_f(new IntegerObject(self)); }
    static Value add(Env *, Integer &, Value);
    static Value sub(Env *, Integer &, Value);
    static Value mul(Env *, IntegerObject *, Value);
    static Value mul(Env *env, Integer &self, Value other) { return mul(env, new IntegerObject(self), other); }
    static Value div(Env *, IntegerObject *, Value);
    static Value div(Env *env, Integer &self, Value other) { return div(env, new IntegerObject(self), other); }
    static Value mod(Env *, Integer &, Value);
    static Value pow(Env *, Integer &, Integer &);
    static Value pow(Env *, Integer &, Value);
    static Value powmod(Env *, Integer &, Integer &, Integer &);
    static Value powmod(Env *, Integer &, Value, Value);
    static Value cmp(Env *, Integer &, Value);
    static Value times(Env *, IntegerObject *, Block *);
    static Value times(Env *env, Integer &self, Block *block) { return times(env, new IntegerObject(self), block); }
    static Value bitwise_and(Env *, IntegerObject *, Value);
    static Value bitwise_and(Env *env, Integer &self, Value other) { return bitwise_and(env, new IntegerObject(self), other); }
    static Value bitwise_or(Env *, IntegerObject *, Value);
    static Value bitwise_or(Env *env, Integer &self, Value other) { return bitwise_or(env, new IntegerObject(self), other); }
    static Value bitwise_xor(Env *, IntegerObject *, Value);
    static Value bitwise_xor(Env *env, Integer &self, Value other) { return bitwise_xor(env, new IntegerObject(self), other); }
    static Value bit_length(Env *, IntegerObject *);
    static Value bit_length(Env *env, Integer &self) { return bit_length(env, new IntegerObject(self)); }
    static Value left_shift(Env *, IntegerObject *, Value);
    static Value left_shift(Env *env, Integer &self, Value other) { return left_shift(env, new IntegerObject(self), other); }
    static Value right_shift(Env *, IntegerObject *, Value);
    static Value right_shift(Env *env, Integer &self, Value other) { return right_shift(env, new IntegerObject(self), other); }
    static Value pred(Env *, IntegerObject *);
    static Value pred(Env *env, Integer &self) { return pred(env, new IntegerObject(self)); }
    static Value size(Env *, IntegerObject *);
    static Value size(Env *env, Integer &self) { return size(env, new IntegerObject(self)); }
    static Value succ(Env *, IntegerObject *);
    static Value succ(Env *env, Integer &self) { return succ(env, new IntegerObject(self)); }
    static Value ceil(Env *, IntegerObject *, Value);
    static Value ceil(Env *env, Integer &self, Value arg) { return ceil(env, new IntegerObject(self), arg); }
    static Value coerce(Env *, IntegerObject *, Value);
    static Value coerce(Env *env, Integer &self, Value other) { return coerce(env, new IntegerObject(self), other); }
    static Value floor(Env *, IntegerObject *, Value);
    static Value floor(Env *env, Integer &self, Value arg) { return floor(env, new IntegerObject(self), arg); }
    static Value gcd(Env *, IntegerObject *, Value);
    static Value gcd(Env *env, Integer &self, Value other) { return gcd(env, new IntegerObject(self), other); }
    static Value abs(Env *, IntegerObject *);
    static Value abs(Env *env, Integer &self) { return abs(env, new IntegerObject(self)); }
    static Value chr(Env *, IntegerObject *, Value);
    static Value chr(Env *env, Integer &self, Value encoding) { return chr(env, new IntegerObject(self), encoding); }
    static Value negate(Env *, IntegerObject *);
    static Value negate(Env *env, Integer &self) { return negate(env, new IntegerObject(self)); }
    static Value numerator(IntegerObject *self) { return IntegerObject::create(self->m_integer); }
    static Value numerator(Integer &self) { return IntegerObject::create(self); }
    static Value complement(Env *, IntegerObject *);
    static Value complement(Env *env, Integer &self) { return complement(env, new IntegerObject(self)); }
    static Value ord(IntegerObject *self) { return IntegerObject::create(self->m_integer); }
    static Value ord(Integer &self) { return IntegerObject::create(self); }
    static Value denominator() { return Value::integer(1); }
    static Value round(Env *, IntegerObject *, Value, Value);
    static Value round(Env *env, Integer &self, Value ndigits, Value half) { return round(env, new IntegerObject(self), ndigits, half); }
    static Value truncate(Env *, IntegerObject *, Value);
    static Value truncate(Env *env, Integer &self, Value ndigits) { return truncate(env, new IntegerObject(self), ndigits); }
    static Value ref(Env *, IntegerObject *, Value, Value);
    static Value ref(Env *env, Integer &self, Value offset_obj, Value size_obj) { return ref(env, new IntegerObject(self), offset_obj, size_obj); }

    static bool neq(Env *, IntegerObject *, Value);
    static bool neq(Env *env, Integer &self, Value other) { return neq(env, new IntegerObject(self), other); }
    static bool eq(Env *, Integer &, Value);
    static bool lt(Env *, IntegerObject *, Value);
    static bool lt(Env *env, Integer &self, Value other) { return lt(env, new IntegerObject(self), other); }
    static bool lte(Env *, IntegerObject *, Value);
    static bool lte(Env *env, Integer &self, Value other) { return lte(env, new IntegerObject(self), other); }
    static bool gt(Env *, IntegerObject *, Value);
    static bool gt(Env *env, Integer &self, Value other) { return gt(env, new IntegerObject(self), other); }
    static bool gte(Env *, IntegerObject *, Value);
    static bool gte(Env *env, Integer &self, Value other) { return gte(env, new IntegerObject(self), other); }
    static bool is_bignum(const IntegerObject *self) { return self->m_integer.is_bignum(); }
    static bool is_bignum(const Integer &self) { return self.is_bignum(); }
    static bool is_fixnum(const IntegerObject *self) { return !is_bignum(self); }
    static bool is_fixnum(const Integer &self) { return self.is_fixnum(); }

    static nat_int_t to_nat_int_t(const IntegerObject *self) { return self->m_integer.to_nat_int_t(); }
    static BigInt to_bigint(const IntegerObject *self) { return self->m_integer.to_bigint(); }
    static BigInt to_bigint(const Integer &self) { return self.to_bigint(); }

    static void assert_fixnum(Env *env, const IntegerObject *self) {
        if (is_bignum(self))
            env->raise("RangeError", "bignum too big to convert into 'long'");
    }

    static void assert_fixnum(Env *env, const Integer &self) {
        if (self.is_bignum())
            env->raise("RangeError", "bignum too big to convert into 'long'");
    }

    virtual String dbg_inspect() const override { return to_s(this); }

    virtual void gc_inspect(char *buf, size_t len) const override {
        snprintf(buf, len, "<IntegerObject %p value=%s is_fixnum=%s>", this, m_integer.to_string().c_str(), m_integer.is_fixnum() ? "true" : "false");
    }

    virtual void visit_children(Visitor &visitor) const override {
        Object::visit_children(visitor);
        if (m_integer.is_bignum())
            visitor.visit(m_integer.bigint_pointer());
    }

private:
    Integer m_integer;
};

}
