#include "json-c/json.h"
#include "natalie.hpp"

using namespace Natalie;

Value init_json(Env *env, Value self) {
    return NilObject::the();
}

static json_object *ruby_to_json(Env *env, Value input) {
    if (input.is_nil()) {
        return json_object_new_null();
    } else if (input.is_true()) {
        return json_object_new_boolean(true);
    } else if (input.is_false()) {
        return json_object_new_boolean(false);
    } else if (input.is_integer()) {
        auto integer = input.integer();
        if (integer.is_bignum() || integer < static_cast<nat_int_t>(std::numeric_limits<int64_t>::min()) || integer > static_cast<nat_int_t>(std::numeric_limits<int64_t>::max())) {
            const auto d = integer.to_double();
            return json_object_new_double_s(d, integer.to_string().c_str());
        }
        return json_object_new_int64(integer.to_nat_int_t());
    } else if (input.is_float()) {
        const auto d = input->as_float()->to_double();
        return json_object_new_double_s(d, input.to_s(env)->c_str());
    } else if (input.is_string()) {
        auto str = input.to_str(env);
        return json_object_new_string_len(str->c_str(), str->bytesize());
    } else if (input.is_array()) {
        auto ary = input->as_array();
        auto res = json_object_new_array_ext(ary->size());
        for (auto elt : *ary)
            json_object_array_add(res, ruby_to_json(env, elt));
        return res;
    } else if (input.is_hash()) {
        auto hash = input->as_hash();
        auto res = json_object_new_object();
        for (auto elt : *hash) {
            auto val = ruby_to_json(env, elt.val);
            json_object_object_add(res, elt.key.to_s(env)->c_str(), val);
        }
        return res;
    } else {
        auto str = input.to_s(env);
        return json_object_new_string_len(str->c_str(), str->bytesize());
    }
}

static Value json_to_ruby(Env *env, json_object *obj, bool symbolize_names) {
    switch (json_object_get_type(obj)) {
    case json_type_null:
        return NilObject::the();
    case json_type_boolean:
        return bool_object(json_object_get_boolean(obj));
    case json_type_int: {
        const auto num = json_object_get_int64(obj);
        if (num == std::numeric_limits<int64_t>::min() || num == std::numeric_limits<int64_t>::max()) {
            String bignum { json_object_get_string(obj) };
            return Value::integer(std::move(bignum));
        }
        return Value::integer(num);
    }
    case json_type_double:
        return new FloatObject { json_object_get_double(obj) };
    case json_type_string:
        return new StringObject { json_object_get_string(obj), static_cast<size_t>(json_object_get_string_len(obj)), Encoding::UTF_8 };
    case json_type_array: {
        const size_t size = json_object_array_length(obj);
        auto ary = new ArrayObject { size };
        for (size_t i = 0; i < size; i++)
            ary->push(json_to_ruby(env, json_object_array_get_idx(obj, i), symbolize_names));
        return ary;
    }
    case json_type_object: {
        auto hash = new HashObject {};
        json_object_object_foreach(obj, key, val) {
            Value key_obj = symbolize_names ? (Value)SymbolObject::intern(key) : (Value)(new StringObject { key, Encoding::UTF_8 });
            hash->put(env, key_obj, json_to_ruby(env, val, symbolize_names));
        }
        return hash;
    }
    default: {
        auto ParserError = fetch_nested_const({ "JSON"_s, "ParserError"_s })->as_class();
        env->raise(ParserError, "Unknown JSON type: {}", json_type_to_name(json_object_get_type(obj)));
    }
    }
}

Value JSON_generate(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 1);
    auto res = ruby_to_json(env, args[0]);
    auto json_string = json_object_to_json_string_ext(res, JSON_C_TO_STRING_PLAIN);
    auto string = new StringObject { json_string, Encoding::ASCII_8BIT };
    json_object_put(res);
    return string;
}

Value JSON_parse(Env *env, Value self, Args &&args, Block *) {
    auto kwargs = args.pop_keyword_hash();
    const auto symbolize_names = kwargs ? kwargs->remove(env, "symbolize_names"_s).is_truthy() : false;
    args.ensure_argc_is(env, 1);
    env->ensure_no_extra_keywords(kwargs);
    auto input = args[0].to_str(env);
    auto tok = json_tokener_new();
    Defer tok_free { [&]() { json_tokener_free(tok); } };
    json_tokener_set_flags(tok, JSON_TOKENER_STRICT | JSON_TOKENER_VALIDATE_UTF8);
    const auto size = input->bytesize();
    // input size needs to include the final '\0'
    auto obj = json_tokener_parse_ex(tok, input->c_str(), size + 1);
    Defer obj_free { [&]() { json_object_put(obj); } };
    auto err = json_tokener_get_error(tok);
    if (err != json_tokener_success) {
        auto ParserError = self->as_module()->const_get("ParserError"_s)->as_class();
        env->raise(ParserError, "{}", json_tokener_error_desc(err));
    }
    if (json_tokener_get_parse_end(tok) < size) {
        auto ParserError = self->as_module()->const_get("ParserError"_s)->as_class();
        env->raise(ParserError, "unexpected token");
    }
    return json_to_ruby(env, obj, symbolize_names);
}
