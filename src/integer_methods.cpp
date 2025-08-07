#include "natalie.hpp"

#include <math.h>

namespace Natalie {

Value IntegerMethods::to_s(Env *env, Integer self, Optional<Value> base_value) {
    if (self == 0)
        return StringObject::create("0");

    nat_int_t base = 10;
    if (base_value) {
        base = convert_to_nat_int_t(env, base_value.value());

        if (base < 2 || base > 36) {
            env->raise("ArgumentError", "invalid radix {}", base);
        }
    }

    if (base == 10)
        return StringObject::create(self.to_string(), Encoding::US_ASCII);

    auto str = StringObject::create("", Encoding::US_ASCII);
    auto num = self;
    bool negative = false;
    if (num < 0) {
        negative = true;
        num *= -1;
    }
    while (num > 0) {
        auto digit = num % base;
        char c;
        if (digit >= 0 && digit <= 9)
            c = digit.to_nat_int_t() + '0';
        else
            c = digit.to_nat_int_t() + 'a' - 10;
        str->prepend_char(env, c);
        num /= base;
    }
    if (negative)
        str->prepend_char(env, '-');
    return str;
}

Value IntegerMethods::to_f(Integer self) {
    return FloatObject::create(self.to_double());
}

Value IntegerMethods::add(Env *env, Integer self, Value arg) {
    if (arg.is_integer()) {
        return self + arg.integer();
    } else if (arg.is_float()) {
        return FloatObject::create(self + arg.as_float()->to_double());
    } else if (!arg.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        if (!lhs.is_integer())
            return lhs.send(env, "+"_s, { rhs });
        arg = rhs;
    }
    arg.assert_integer(env);

    return self + arg.integer();
}

Value IntegerMethods::sub(Env *env, Integer self, Value arg) {
    if (arg.is_integer()) {
        return self - arg.integer();
    } else if (arg.is_float()) {
        double result = self.to_double() - arg.as_float()->to_double();
        return FloatObject::create(result);
    } else if (!arg.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        if (!lhs.is_integer())
            return lhs.send(env, "-"_s, { rhs });
        arg = rhs;
    }
    arg.assert_integer(env);

    return self - arg.integer();
}

Value IntegerMethods::mul(Env *env, Integer self, Value arg) {
    if (arg.is_float()) {
        double result = self.to_double() * arg.as_float()->to_double();
        return FloatObject::create(result);
    } else if (!arg.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        if (!lhs.is_integer())
            return lhs.send(env, "*"_s, { rhs });
        arg = rhs;
    }

    arg.assert_integer(env);

    if (self == 0 || arg.integer() == 0)
        return Value::integer(0);

    return self * arg.integer();
}

Value IntegerMethods::div(Env *env, Integer self, Value arg) {
    if (arg.is_float()) {
        double result = self / arg.as_float()->to_double();
        if (isnan(result))
            return FloatObject::nan();
        return FloatObject::create(result);
    } else if (!arg.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        if (!lhs.is_integer())
            return lhs.send(env, "/"_s, { rhs });
        arg = rhs;
    }
    arg.assert_integer(env);

    auto other = arg.integer();
    if (other == 0)
        env->raise("ZeroDivisionError", "divided by 0");

    return self / other;
}

Value IntegerMethods::mod(Env *env, Integer self, Value arg) {
    Integer argument;
    if (arg.is_float()) {
        auto f = FloatObject::create(self.to_double());
        return f->mod(env, arg);
    } else if (!arg.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        if (!lhs.is_integer())
            return lhs.send(env, "%"_s, { rhs });
        arg = rhs;
    }

    arg.assert_integer(env);
    argument = arg.integer();

    if (argument == 0)
        env->raise("ZeroDivisionError", "divided by 0");

    return self % argument;
}

Value IntegerMethods::pow(Env *env, Integer self, Integer arg) {
    if (self == 0 && arg < 0)
        env->raise("ZeroDivisionError", "divided by 0");

    // NATFIXME: If a negative number is passed we want to return a Rational
    if (arg < 0) {
        auto denominator = Natalie::pow(self, -arg);
        return RationalObject::create(Value::integer(1), denominator);
    }

    if (arg == 0)
        return Value::integer(1);
    else if (arg == 1)
        return self;

    if (self == 0)
        return Value::integer(0);
    else if (self == 1)
        return Value::integer(1);
    else if (self == -1)
        return Value::integer(arg % 2 ? 1 : -1);

    // NATFIXME: Ruby has a really weird max bignum value that is calculated by the words needed to store a bignum
    // The calculation that we do is pretty much guessed to be in the direction of ruby. However, we should do more research about this limit...
    size_t length = self.to_string().length();
    constexpr const size_t BIGINT_LIMIT = 8 * 1024 * 1024;
    if (length > BIGINT_LIMIT || length * arg > (nat_int_t)BIGINT_LIMIT)
        env->raise("ArgumentError", "exponent is too large");

    return Natalie::pow(self, arg);
}

Value IntegerMethods::pow(Env *env, Integer self, Value arg) {
    if (arg.is_integer())
        return pow(env, self, arg.integer());

    if ((arg.is_float() || arg.is_rational()) && self < 0) {
        auto comp = ComplexObject::create(self);
        return comp->send(env, "**"_s, { arg });
    }

    if (arg.is_float()) {
        auto f = FloatObject::create(self.to_double());
        return f->pow(env, arg);
    }

    if (!arg.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        if (!lhs.is_integer())
            return lhs.send(env, "**"_s, { rhs });
        arg = rhs;
    }

    arg.assert_integer(env);

    return pow(env, self, arg.integer());
}

Value IntegerMethods::powmod(Env *env, Integer self, Value exponent, Optional<Value> mod) {
    if (exponent.is_integer() && exponent.integer().is_negative() && mod)
        env->raise("RangeError", "2nd argument not allowed when first argument is negative");

    auto powd = pow(env, self, exponent);

    if (!mod)
        return powd;

    if (!mod->is_integer())
        env->raise("TypeError", "2nd argument not allowed unless all arguments are integers");

    auto modi = mod->integer();
    if (modi.is_zero())
        env->raise("ZeroDivisionError", "cannot divide by zero");

    return powd.integer() % modi;
}

Value IntegerMethods::cmp(Env *env, Integer self, Value arg) {
    auto is_comparable_with = [](Value arg) -> bool {
        return arg.is_integer() || (arg.is_float() && !arg.as_float()->is_nan());
    };

    // Check if we might want to coerce the value
    if (!is_comparable_with(arg)) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self, Natalie::CoerceInvalidReturnValueMode::Allow);
        if (!is_comparable_with(lhs))
            return lhs.send(env, "<=>"_s, { rhs });
        arg = rhs;
    }

    // Check if comparable
    if (!is_comparable_with(arg))
        return Value::nil();

    if (lt(env, self, arg)) {
        return Value::integer(-1);
    } else if (eq(env, self, arg)) {
        return Value::integer(0);
    } else {
        return Value::integer(1);
    }
}

bool IntegerMethods::eq(Env *env, Integer self, Value other) {
    if (other.is_integer())
        return self == other.integer();

    if (other.is_float()) {
        auto *f = other.as_float();
        return !f->is_nan() && self == f->to_double();
    }

    if (!other.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, other, self);
        if (!lhs.is_integer())
            return lhs.send(env, "=="_s, { rhs }).is_truthy();
        other = rhs;
    }

    if (other.is_integer())
        return self == other.integer();

    return other.send(env, "=="_s, { self }).is_truthy();
}

bool IntegerMethods::lt(Env *env, Integer self, Value other) {
    if (other.is_float()) {
        if (other.as_float()->is_nan())
            return false;
        return self < other.as_float()->to_double();
    }

    if (!other.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, other, self);
        if (!lhs.is_integer())
            return lhs.send(env, "<"_s, { rhs }).is_truthy();
        other = rhs;
    }

    if (other.is_integer())
        return self < other.integer();

    if (other.respond_to(env, "coerce"_s)) {
        auto result = Natalie::coerce(env, other, self);
        return result.first.send(env, "<"_s, { result.second }).is_truthy();
    }

    env->raise("ArgumentError", "comparison of Integer with {} failed", other.inspected(env));
}

bool IntegerMethods::lte(Env *env, Integer self, Value other) {
    if (other.is_float()) {
        if (other.as_float()->is_nan())
            return false;
        return self <= other.as_float()->to_double();
    }

    if (!other.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, other, self);
        if (!lhs.is_integer())
            return lhs.send(env, "<="_s, { rhs }).is_truthy();
        other = rhs;
    }

    if (other.is_integer())
        return self <= other.integer();

    if (other.respond_to(env, "coerce"_s)) {
        auto result = Natalie::coerce(env, other, self);
        return result.first.send(env, "<="_s, { result.second }).is_truthy();
    }

    env->raise("ArgumentError", "comparison of Integer with {} failed", other.inspected(env));
}

bool IntegerMethods::gt(Env *env, Integer self, Value other) {
    if (other.is_float()) {
        if (other.as_float()->is_nan())
            return false;
        return self > other.as_float()->to_double();
    }

    if (!other.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, other, self, Natalie::CoerceInvalidReturnValueMode::Raise);
        if (!lhs.is_integer())
            return lhs.send(env, ">"_s, { rhs }).is_truthy();
        other = rhs;
    }

    if (other.is_integer())
        return self > other.integer();

    if (other.respond_to(env, "coerce"_s)) {
        auto result = Natalie::coerce(env, other, self);
        return result.first.send(env, ">"_s, { result.second }).is_truthy();
    }

    env->raise("ArgumentError", "comparison of Integer with {} failed", other.inspected(env));
}

bool IntegerMethods::gte(Env *env, Integer self, Value other) {
    if (other.is_float()) {
        if (other.as_float()->is_nan())
            return false;
        return self >= other.as_float()->to_double();
    }

    if (!other.is_integer()) {
        auto [lhs, rhs] = Natalie::coerce(env, other, self, Natalie::CoerceInvalidReturnValueMode::Raise);
        if (!lhs.is_integer())
            return lhs.send(env, ">="_s, { rhs }).is_truthy();
        other = rhs;
    }

    if (other.is_integer())
        return self >= other.integer();

    if (other.respond_to(env, "coerce"_s)) {
        auto result = Natalie::coerce(env, other, self);
        return result.first.send(env, ">="_s, { result.second }).is_truthy();
    }

    env->raise("ArgumentError", "comparison of Integer with {} failed", other.inspected(env));
}

Value IntegerMethods::times(Env *env, Integer self, Block *block) {
    if (!block) {
        auto enumerator = Value(self).send(env, "enum_for"_s, { "times"_s });
        enumerator->ivar_set(env, "@size"_s, self < 0 ? Value::integer(0) : self);
        return enumerator;
    }

    if (self <= 0)
        return self;

    for (Integer i = 0; i < self; ++i) {
        block->run(env, Args({ i }, false), nullptr);
    }
    return self;
}

Value IntegerMethods::bitwise_and(Env *env, Integer self, Value arg) {
    if (!arg.is_integer() && arg.respond_to(env, "coerce"_s)) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        auto and_symbol = "&"_s;
        if (!lhs.is_integer() && lhs.respond_to(env, and_symbol))
            return lhs.send(env, and_symbol, { rhs });
        arg = rhs;
    }
    arg.assert_integer(env);

    return self & arg.integer();
}

Value IntegerMethods::bitwise_or(Env *env, Integer self, Value arg) {
    Integer argument;
    if (!arg.is_integer() && arg.respond_to(env, "coerce"_s)) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        auto or_symbol = "|"_s;
        if (!lhs.is_integer() && lhs.respond_to(env, or_symbol))
            return lhs.send(env, or_symbol, { rhs });
        arg = rhs;
    }
    arg.assert_integer(env);

    return self | arg.integer();
}

Value IntegerMethods::bitwise_xor(Env *env, Integer self, Value arg) {
    Integer argument;
    if (!arg.is_integer() && arg.respond_to(env, "coerce"_s)) {
        auto [lhs, rhs] = Natalie::coerce(env, arg, self);
        auto xor_symbol = "^"_s;
        if (!lhs.is_integer() && lhs.respond_to(env, xor_symbol))
            return lhs.send(env, xor_symbol, { rhs });
        arg = rhs;
    }
    arg.assert_integer(env);

    return self ^ arg.integer();
}

Value IntegerMethods::left_shift(Env *env, Integer self, Value arg) {
    if (self.is_zero())
        return Value::integer(0);
    auto integer = arg.to_int(env);
    if (integer.is_bignum()) {
        if (self.is_negative() && integer.is_negative())
            return Value::integer(-1);
        else if (integer.is_negative())
            return Value::integer(0);
        else
            env->raise("RangeError", "shift width too big");
    }

    auto nat_int = integer.to_nat_int_t();

    if (nat_int < 0)
        return right_shift(env, self, Value::integer(-nat_int));

    if (nat_int >= (static_cast<nat_int_t>(1) << 32) || nat_int <= -(static_cast<nat_int_t>(1) << 32))
        env->raise("RangeError", "shift width too big");

    return self << nat_int;
}

Value IntegerMethods::right_shift(Env *env, Integer self, Value arg) {
    if (self.is_zero())
        return Value::integer(0);
    auto integer = arg.to_int(env);
    if (integer.is_bignum()) {
        if (integer.is_negative())
            env->raise("RangeError", "shift width too big");
        else if (self.is_negative())
            return Value::integer(-1);
        else
            return Value::integer(0);
    }

    auto nat_int = integer.to_nat_int_t();

    if (nat_int < 0)
        return left_shift(env, self, Value::integer(-nat_int));

    return self >> nat_int;
}

Value IntegerMethods::size(Env *env, Integer self) {
    if (self.is_bignum()) {
        const nat_int_t bitstring_size = to_s(env, self, Value::integer(2)).as_string()->bytesize();
        return Value::integer((bitstring_size + 7) / 8);
    }
    return Value::integer(sizeof(nat_int_t));
}

Value IntegerMethods::coerce(Env *env, Value self, Value arg) {
    ArrayObject *ary = ArrayObject::create();
    if (arg.is_integer()) {
        ary->push(arg);
        ary->push(self);
    } else if (arg.is_string()) {
        ary->push(self.send(env, "Float"_s, { arg }));
        ary->push(self.send(env, "to_f"_s));
    } else {
        if (!arg.is_nil() && !arg.is_float() && arg.respond_to(env, "to_f"_s)) {
            arg = arg.send(env, "to_f"_s);
        }
        if (!arg.is_float())
            env->raise("TypeError", "can't convert {} into Float", arg.inspected(env));

        ary->push(arg);
        ary->push(self.send(env, "to_f"_s));
    }
    return ary;
}

Value IntegerMethods::ceil(Env *env, Integer self, Optional<Value> arg) {
    if (!arg)
        return self;

    arg->assert_integer(env);

    auto precision = arg->integer().to_nat_int_t();
    if (precision >= 0)
        return self;

    double f = ::pow(10, precision);
    auto result = ::ceil(self.to_nat_int_t() * f) / f;

    return Value::integer(result);
}

Value IntegerMethods::floor(Env *env, Integer self, Optional<Value> arg) {
    if (!arg)
        return self;

    arg->assert_integer(env);

    auto precision = arg->integer().to_nat_int_t();
    if (precision >= 0)
        return self;

    double f = ::pow(10, precision);
    auto result = ::floor(self.to_nat_int_t() * f) / f;

    return Value::integer(result);
}

Value IntegerMethods::gcd(Env *env, Integer self, Value divisor) {
    divisor.assert_integer(env);
    return Natalie::gcd(self, divisor.integer());
}

Value IntegerMethods::chr(Env *env, Integer self, Optional<Value> encoding_arg) {
    if (self.is_bignum())
        env->raise("RangeError", "bignum out of char range");
    else if (self < 0 || self > (nat_int_t)UINT_MAX)
        env->raise("RangeError", "{} out of char range", self.to_string());

    Value encoding;
    if (encoding_arg) {
        encoding = encoding_arg.value();
        if (!encoding.is_encoding()) {
            encoding.assert_type(env, Object::Type::String, "String");
            encoding = EncodingObject::find(env, encoding);
        }
    } else if (self <= 127) {
        encoding = EncodingObject::get(Encoding::US_ASCII);
    } else if (self < 256) {
        encoding = EncodingObject::get(Encoding::ASCII_8BIT);
    } else if (EncodingObject::default_internal()) {
        encoding = EncodingObject::default_internal();
    } else {
        env->raise("RangeError", "{} out of char range", self.to_string());
    }

    auto encoding_obj = encoding.as_encoding();
    if (!encoding_obj->in_encoding_codepoint_range(self.to_nat_int_t()))
        env->raise("RangeError", "{} out of char range", self.to_string());

    if (!encoding_obj->valid_codepoint(self.to_nat_int_t())) {
        auto hex = String();
        hex.append_sprintf("0x%X", self.to_nat_int_t());

        auto encoding_name = encoding_obj->name()->string();
        env->raise("RangeError", "invalid codepoint {} in {}", hex, encoding_name);
    }

    auto encoded = encoding_obj->encode_codepoint(self.to_nat_int_t());
    return StringObject::create(encoded, encoding_obj);
}

Value IntegerMethods::sqrt(Env *env, Value arg) {
    auto argument = arg.to_int(env);

    if (argument < 0) {
        auto domain_error = fetch_nested_const({ "Math"_s, "DomainError"_s });
        auto message = StringObject::create("Numerical argument is out of domain - \"isqrt\"");
        auto exception = ExceptionObject::create(domain_error.as_class(), message);
        env->raise_exception(exception);
    }

    return Natalie::sqrt(argument);
}

Value IntegerMethods::round(Env *env, Integer self, Optional<Value> ndigits, Optional<Value> half) {
    if (!ndigits)
        return self;

    int digits = convert_to_int(env, ndigits.value());
    RoundingMode rounding_mode = rounding_mode_from_value(env, half);

    if (digits >= 0)
        return self;

    auto result = self;
    auto dividend = Natalie::pow(Integer(10), -digits);

    auto dividend_half = dividend / 2;
    auto remainder = result.modulo_c(dividend);
    auto remainder_abs = Natalie::abs(remainder);

    if (remainder_abs < dividend_half) {
        result -= remainder;
    } else if (remainder_abs > dividend_half) {
        result += dividend - remainder;
    } else {
        switch (rounding_mode) {
        case RoundingMode::Up:
            result += remainder;
            break;
        case RoundingMode::Down:
            result -= remainder;
            break;
        case RoundingMode::Even:
            auto digit = result.modulo_c(dividend * 10).div_c(dividend);
            if (digit % 2 == 0) {
                result -= remainder;
            } else {
                result += remainder;
            }
            break;
        }
    }

    return result;
}

Value IntegerMethods::truncate(Env *env, Integer self, Optional<Value> ndigits) {
    if (!ndigits)
        return self;

    int digits = convert_to_int(env, ndigits.value());

    if (digits >= 0)
        return self;

    auto result = self;
    auto dividend = Natalie::pow(Integer(10), -digits);
    auto remainder = result.modulo_c(dividend);

    return result - remainder;
}

Value IntegerMethods::ref(Env *env, Integer self, Value offset_obj, Optional<Value> size_obj) {
    auto from_offset_and_size = [self, env](Optional<nat_int_t> offset_or_empty, Optional<nat_int_t> size_or_empty = {}) -> Value {
        auto offset = offset_or_empty.value_or(0);

        if (!size_or_empty.present() && offset < 0)
            return Value::integer(0);

        auto size = size_or_empty.value_or(1);

        Integer result;
        if (offset < 0)
            result = self << -offset;
        else
            result = self >> offset;

        if (size >= 0)
            result = result & ((1 << size) - 1);

        if (result != 0 && !offset_or_empty.present())
            env->raise("ArgumentError", "The beginless range for Integer#[] results in infinity");

        return result;
    };

    if (!size_obj && offset_obj.is_range()) {
        auto range = offset_obj.as_range();

        Optional<nat_int_t> begin;
        if (!range->begin().is_nil()) {
            auto begin_obj = range->begin().to_int(env);
            begin = begin_obj.to_nat_int_t();
        }

        Optional<nat_int_t> end;
        if (!range->end().is_nil()) {
            auto end_obj = range->end().to_int(env);
            end = end_obj.to_nat_int_t();
        }

        Optional<nat_int_t> size;
        if (!end || (begin && end.value() < begin.value()))
            size = -1;
        else if (end)
            size = end.value() - begin.value_or(0) + 1;

        return from_offset_and_size(begin, size);
    } else {
        auto offset_integer = offset_obj.to_int(env);
        if (offset_integer.is_bignum())
            return Value::integer(0);

        auto offset = offset_integer.to_nat_int_t();

        Optional<nat_int_t> size;
        if (size_obj) {
            auto size_integer = size_obj->to_int(env);
            if (size_integer.is_bignum())
                env->raise("RangeError", "shift width too big");

            size = size_integer.to_nat_int_t();
        }

        return from_offset_and_size(offset, size);
    }
}

nat_int_t IntegerMethods::convert_to_nat_int_t(Env *env, Value arg) {
    auto integer = arg.to_int(env);
    return convert_to_native_type<nat_int_t>(env, integer);
}

int IntegerMethods::convert_to_int(Env *env, Value arg) {
    auto result = convert_to_nat_int_t(env, arg);

    if (result < std::numeric_limits<int>::min())
        env->raise("RangeError", "integer {} too small to convert to 'int'");
    else if (result > std::numeric_limits<int>::max())
        env->raise("RangeError", "integer {} too big to convert to 'int'");

    return (int)result;
}

gid_t IntegerMethods::convert_to_gid(Env *env, Value arg) {
    if (arg.is_nil()) return (gid_t)(-1); // special case for nil
    auto result = convert_to_nat_int_t(env, arg);
    // this lower limit may look incorrect but experimentally matches MRI behavior
    if (result < std::numeric_limits<int>::min())
        env->raise("RangeError", "integer {} too small to convert to 'unsigned int'", result);
    else if (result > std::numeric_limits<unsigned int>::max())
        env->raise("RangeError", "integer {} too big to convert to 'unsigned int'", result);
    return (gid_t)result;
}

uid_t IntegerMethods::convert_to_uid(Env *env, Value arg) {
    if (arg.is_nil()) return (uid_t)(-1); // special case for nil
    auto result = convert_to_nat_int_t(env, arg);
    // this lower limit may look incorrect but experimentally matches MRI behavior
    if (result < std::numeric_limits<int>::min())
        env->raise("RangeError", "integer {} too small to convert to 'unsigned int'", result);
    else if (result > std::numeric_limits<unsigned int>::max())
        env->raise("RangeError", "integer {} too big to convert to 'unsigned int'", result);
    return (uid_t)result;
}

}
