/************************************************

  bubblebabble.c - BubbleBabble encoding support

  $Author$
  created at: Fri Oct 13 18:31:42 JST 2006

  Copyright (C) 2006 Akinori MUSHA

  $Id$

************************************************/

#include "natalie.hpp"

static Value
bubblebabble_str_new(Env *env, Value str_digest)
{
    const char *digest;
    size_t digest_len;
    char *p;
    size_t i, j, seed = 1;
    static const char vowels[] = {
        'a', 'e', 'i', 'o', 'u', 'y'
    };
    static const char consonants[] = {
        'b', 'c', 'd', 'f', 'g', 'h', 'k', 'l', 'm', 'n',
        'p', 'r', 's', 't', 'v', 'z', 'x'
    };

    auto str_digest_to_str = str_digest->to_str(env);
    digest = str_digest_to_str->c_str();
    digest_len = str_digest_to_str->bytesize();

    if ((LONG_MAX - 2) / 3 < (digest_len | 1)) {
        env->raise("RuntimeError", "digest string too long");
    }

    String str { (digest_len | 1) * 3 + 2, '\0' };
    p = &str[0];

    i = j = 0;
    p[j++] = 'x';

    for (;;) {
        unsigned char byte1, byte2;

        if (i >= digest_len) {
            p[j++] = vowels[seed % 6];
            p[j++] = consonants[16];
            p[j++] = vowels[seed / 6];
            break;
        }

        byte1 = digest[i++];
        p[j++] = vowels[(((byte1 >> 6) & 3) + seed) % 6];
        p[j++] = consonants[(byte1 >> 2) & 15];
        p[j++] = vowels[((byte1 & 3) + (seed / 6)) % 6];

        if (i >= digest_len) {
            break;
        }

        byte2 = digest[i++];
        p[j++] = consonants[(byte2 >> 4) & 15];
        p[j++] = '-';
        p[j++] = consonants[byte2 & 15];

        seed = (seed * 5 + byte1 * 7 + byte2) % 36;
    }

    p[j] = 'x';

    return new StringObject { str, EncodingObject::get(Encoding::ASCII_8BIT) };
}

/* Document-method: Digest::bubblebabble
 *
 * call-seq:
 *     Digest.bubblebabble(string) -> bubblebabble_string
 *
 * Returns a BubbleBabble encoded version of a given _string_.
 */
static Value
rb_digest_s_bubblebabble(Env *env, Value klass, Args args, Block *)
{
    args.ensure_argc_is(env, 1);
    auto str = args.at(0);
    return bubblebabble_str_new(env, str);
}

/* Document-method: Digest::Class::bubblebabble
 *
 * call-seq:
 *     Digest::Class.bubblebabble(string, ...) -> hash_string
 *
 * Returns the BubbleBabble encoded hash value of a given _string_.
 */
static Value
rb_digest_class_s_bubblebabble(Env *env, Value klass, Args args, Block *)
{
    return bubblebabble_str_new(env, klass->send(env, "digest"_s, args));
}

/* Document-method: Digest::Instance#bubblebabble
 *
 * call-seq:
 *     digest_obj.bubblebabble -> hash_string
 *
 * Returns the resulting hash value in a Bubblebabble encoded form.
 */
static Value
rb_digest_instance_bubblebabble(Env *env, Value self, Args args, Block *)
{
    return bubblebabble_str_new(env, self->send(env, "digest"_s));
}

/*
 * This module adds some methods to Digest classes to perform
 * BubbleBabble encoding.
 */
Value init_bubblebabble(Env *env, Value self) {
#undef rb_intern
    Value rb_mDigest, rb_mDigest_Instance, rb_cDigest_Class;

#if 0
    rb_mDigest = rb_define_module("Digest");
    rb_mDigest_Instance = rb_define_module_under(rb_mDigest, "Instance");
    rb_cDigest_Class = rb_define_class_under(rb_mDigest, "Class", rb_cObject);
#endif
    rb_mDigest = GlobalEnv::the()->Object()->const_get("Digest"_s);
    if (!rb_mDigest) {
        rb_mDigest = new ModuleObject { "Digest" };
        GlobalEnv::the()->Object()->const_set("Digest"_s, rb_mDigest);
    }
    rb_mDigest_Instance = rb_mDigest->const_get("Instance"_s);
    if (!rb_mDigest_Instance) {
        rb_mDigest_Instance = new ModuleObject { "Instance" };
        rb_mDigest->const_set("Instance"_s, rb_mDigest_Instance);
    }
    rb_cDigest_Class = rb_mDigest->const_get("Class"_s);
    if (!rb_cDigest_Class) {
        rb_cDigest_Class = GlobalEnv::the()->Object()->subclass(env, "Class");
        rb_mDigest->const_set("Class"_s, rb_cDigest_Class);
    }

    rb_mDigest->define_method(env, "bubblebabble"_s, rb_digest_s_bubblebabble, 1);
    rb_mDigest->module_function(env, "bubblebabble"_s);
    rb_cDigest_Class->define_singleton_method(env, "bubblebabble"_s, rb_digest_class_s_bubblebabble, -1);
    rb_mDigest_Instance->define_method(env, "bubblebabble"_s, rb_digest_instance_bubblebabble, 0);

    return NilObject::the();
}