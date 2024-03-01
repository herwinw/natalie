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

static Value ruby_cleanup_wrapper(Env *env, Value, Args, Block *) {
    if (ruby_cleanup(0))
        env->raise("Exception", "Error during ruby_cleanup()");

    ruby_init_loadpath();

    return NilObject::the();
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
