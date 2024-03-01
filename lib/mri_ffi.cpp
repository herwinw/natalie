// These are defined in onigmo.h as well
#ifdef RUBY_SYMBOL_EXPORT_BEGIN
#undef RUBY_SYMBOL_EXPORT_BEGIN
#endif
#ifdef RUBY_SYMBOL_EXPORT_END
#undef RUBY_SYMBOL_EXPORT_END
#endif

// These are defined in macros.hpp as well
#ifdef NO_SANITIZE_ADDRESS
#undef NO_SANITIZE_ADDRESS
#endif

#include <ruby.h>

#ifndef RUBY_SYMBOL_EXPORT_BEGIN
#error "RUBY_SYMBOL_EXPORT_BEGIN no longer defined"
#endif
#ifndef RUBY_SYMBOL_EXPORT_END
#error "RUBY_SYMBOL_EXPORT_END no longer defined"
#endif
#ifndef NO_SANITIZE_ADDRESS
#error "NO_SANITIZE_ADDRESS no longer defined"
#endif

#include <limits>

static Value ruby_cleanup_wrapper(Env *env, Value, Args, Block *) {
    if (ruby_cleanup(0))
        env->raise("Exception", "Error during ruby_cleanup()");

    ruby_init_loadpath();

    return NilObject::the();
}

static VALUE nat_to_mri(Env *env, Value value) {
    if (value->is_string()) {
        auto str = value->as_string();
        return rb_str_new(str->c_str(), str->bytesize());
    } else if (value->is_integer()) {
        if (value->as_integer()->is_bignum())
            env->raise("ArgumentError", "Cannot convert int outside of `long` range to MRI representation");
        const auto integer = value->as_integer()->to_nat_int_t();
        if (integer < std::numeric_limits<long>::min() || integer > std::numeric_limits<long>::max())
            env->raise("ArgumentError", "Cannot convert int outside of `long` range to MRI representation");
        return LONG2FIX(integer);
    } else if (value->is_true()) {
        return Qtrue;
    } else if (value->is_false()) {
        return Qfalse;
    } else {
        env->raise("ArgumentError", "Cannot convert type {} to MRI representation", value->klass()->inspect_str());
    }
    NAT_UNREACHABLE();
}

Value init_mri_ffi(Env *env, Value self) {
    if (ruby_setup())
        env->raise("Exception", "Error during ruby_setup()");

    auto cleanup = Block { env, self, ruby_cleanup_wrapper, 0 };
    // Remove for now, this segfaults
    // KernelModule::at_exit(env, &cleanup);

    return NilObject::the();
}

Value MriFfi_hello_world(Env *env, Value self, Args args, Block *) {
    args.ensure_argc_is(env, 0);

    VALUE hello_world_str = rb_str_new_cstr("Hello world!");
    rb_funcall(rb_mKernel, rb_intern("puts"), 1, hello_world_str);

    return NilObject::the();
}

Value MriFfi_load_mri_extension(Env *env, Value self, Args args, Block *) {
    args.ensure_argc_is(env, 1);

    auto filename = args[0]->to_str(env);
    rb_require(filename->c_str());

    return NilObject::the();
}

Value MriFfi_my_fixed_args_method(Env *env, Value self, Args args, Block *) {
    args.ensure_argc_is(env, 3);

    auto receiver = nat_to_mri(env, args[0]);
    auto arg1 = nat_to_mri(env, args[1]);
    auto arg2 = nat_to_mri(env, args[2]);
    (void)rb_funcall(receiver, rb_intern("my_fixed_args_method"), 2, arg1, arg2);

    return NilObject::the();
}
