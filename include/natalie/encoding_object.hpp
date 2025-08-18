#pragma once

#include <assert.h>
#include <initializer_list>

#include "natalie/array_object.hpp"
#include "natalie/class_object.hpp"
#include "natalie/encodings.hpp"
#include "natalie/forward.hpp"
#include "natalie/global_env.hpp"
#include "natalie/macros.hpp"
#include "natalie/object.hpp"
#include "tm/string_view.hpp"

namespace Natalie {

enum CaseMapType : uint8_t {
    CaseMapFull = 0,
    CaseMapAscii = 1,
    CaseMapTurkicAzeri = 2,
    CaseMapLithuanian = 4,
    CaseMapFold = 8,
};

const int SPECIAL_CASE_LOWER_MAX_SIZE = 2;
const int SPECIAL_CASE_TITLE_MAX_SIZE = 3;
const int SPECIAL_CASE_UPPER_MAX_SIZE = 3;

struct SpecialCasingEntry {
    uint32_t code;
    uint32_t lower[SPECIAL_CASE_LOWER_MAX_SIZE];
    uint32_t title[SPECIAL_CASE_TITLE_MAX_SIZE];
    uint32_t upper[SPECIAL_CASE_UPPER_MAX_SIZE];
};

extern nat_int_t lcase_map[];
extern nat_int_t ucase_map[];
extern nat_int_t tcase_map[];
extern nat_int_t lcase_index[];
extern nat_int_t ucase_index[];
extern nat_int_t tcase_index[];
extern const int special_casing_map_size;
extern SpecialCasingEntry special_casing_map[];

using namespace TM;

class EncodingObject : public Object {
public:
    EncodingObject();

    EncodingObject(ClassObject *klass)
        : Object { Object::Type::Encoding, klass } { }

    EncodingObject(Encoding, std::initializer_list<const String>);

    // Try to get rid of this
    Encoding num() const { return m_num; }

    const StringObject *name() const;
    Value name(Env *);

    ArrayObject *names(Env *) const;

    Value inspect(Env *) const;

    virtual bool in_encoding_codepoint_range(nat_int_t codepoint) const { NAT_UNREACHABLE(); }
    virtual bool is_ascii_compatible() const { return false; } // default
    virtual bool is_dummy() const { return false; }

    virtual bool valid_codepoint(nat_int_t codepoint) const = 0;

    virtual std::tuple<bool, int, nat_int_t> next_codepoint(const String &, size_t *) const;

    virtual std::pair<bool, StringView> prev_char(const String &, size_t *) const = 0;
    virtual std::pair<bool, StringView> next_char(const String &, size_t *) const = 0;

    bool is_valid_codepoint_boundary(const String &string, size_t index) const {
        return next_char(string, &index).first;
    }

    // NOTE: This is a naiive and wasteful fallback; we should override this
    // in each encoding where a more efficient approach is possible.
    virtual bool check_string_valid_in_encoding(const String &string) const {
        size_t index = 0;
        for (;;) {
            auto [valid, length, codepoint] = next_codepoint(string, &index);
            if (!valid)
                return false;
            if (length == 0)
                break;
        }
        return true;
    }

    virtual StringView next_grapheme_cluster(const String &str, size_t *index) const {
        auto [_valid, view] = next_char(str, index);
        return view;
    }

    enum class EncodeInvalidOption {
        Raise,
        Replace,
    };

    enum class EncodeUndefOption {
        Raise,
        Replace,
    };

    enum class EncodeNewlineOption {
        None,
        Cr,
        Crlf,
        Universal,
    };

    enum class EncodeXmlOption {
        None,
        Attr,
        Text,
    };

    struct EncodeOptions {
        EncodeInvalidOption invalid_option = EncodeInvalidOption::Raise;
        EncodeUndefOption undef_option = EncodeUndefOption::Raise;
        EncodeNewlineOption newline_option = EncodeNewlineOption::None;
        EncodeXmlOption xml_option = EncodeXmlOption::None;
        StringObject *replace_option = nullptr;
        Value fallback_option;
    };

    virtual Value encode(Env *, EncodingObject *, StringObject *, EncodeOptions) const;

    virtual bool is_printable_char(const nat_int_t c) const;
    virtual void append_escaped_char(String &str, nat_int_t c) const = 0;
    virtual String encode_codepoint(nat_int_t codepoint) const = 0;
    virtual nat_int_t decode_codepoint(StringView &str) const = 0;

    virtual nat_int_t to_unicode_codepoint(nat_int_t codepoint) const = 0;
    virtual nat_int_t from_unicode_codepoint(nat_int_t codepoint) const = 0;

    virtual bool is_single_byte_encoding() const = 0;

    virtual bool is_compatible_with(EncodingObject *) const;

    [[noreturn]] void raise_encoding_invalid_byte_sequence_error(Env *, const String &, size_t) const;
    [[noreturn]] void raise_compatibility_error(Env *, const EncodingObject *) const;

    static HashObject *aliases(Env *);
    static Value find(Env *, Value);
    static ArrayObject *list(Env *env);
    static ArrayObject *name_list(Env *env);
    static const TM::Vector<EncodingObject *> &encodings() { return EncodingObject::s_encoding_list; }
    static EncodingObject *default_external() { return s_default_external; }
    static EncodingObject *default_internal() { return s_default_internal; }
    static EncodingObject *locale() { return s_locale; }
    static EncodingObject *filesystem() { return s_filesystem; }
    static EncodingObject *set_default_external(Env *, Value);
    static EncodingObject *set_default_internal(Env *, Value);
    static EncodingObject *get(Encoding encoding) { return s_encoding_list.at(static_cast<size_t>(encoding) - 1); }
    static Value locale_charmap();
    static void initialize_defaults(Env *);

    static EncodingObject *find_encoding_by_name(Env *env, String name);
    static EncodingObject *find_encoding(Env *env, Value encoding);

    // must pass a buffer of nat_int_t to this function; uint8_t return is number of codepoints written
    static uint8_t codepoint_to_lowercase(nat_int_t codepoint, nat_int_t result[], uint8_t flags = CaseMapFull);
    static uint8_t codepoint_to_uppercase(nat_int_t codepoint, nat_int_t result[], uint8_t flags = CaseMapFull);
    static uint8_t codepoint_to_titlecase(nat_int_t codepoint, nat_int_t result[], uint8_t flags = CaseMapFull);

    static void init_special_casing_map();
    static SpecialCasingEntry find_special_casing_map_entry(nat_int_t codepoint);

    static Value casefold_common(nat_int_t codepoint);
    static Value casefold_full(nat_int_t codepoint);
    static Value casefold_simple(nat_int_t codepoint);

    virtual TM::String dbg_inspect(int indent = 0) const override {
        return TM::String::format("<EncodingObject {h} name={}>", this, m_names[0]);
    }

private:
    Vector<String> m_names {};
    Encoding m_num;

    static inline TM::Vector<EncodingObject *> s_encoding_list { EncodingCount, nullptr };
    static inline EncodingObject *s_default_internal = nullptr;
    // external, locale and filesystem are set by a static initializer function
    static inline EncodingObject *s_default_external = nullptr;
    static inline EncodingObject *s_locale = nullptr;
    static inline EncodingObject *s_filesystem = nullptr;
};

}
