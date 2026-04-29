#include "natalie.hpp"
#include <mutex>
#include <syslog.h>

using namespace Natalie;

static std::recursive_mutex syslog_mutex;
static char *syslog_ident = nullptr;
static int syslog_options = -1;
static int syslog_facility = -1;
static int syslog_mask = -1;
static bool syslog_opened = false;

Value init_syslog(Env *env, Value self) {
    return Value::nil();
}

static void syslog_write(Env *env, int pri, Args &&args) {
    {
        std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
        if (!syslog_opened)
            env->raise("RuntimeError", "must open syslog before write");
    }
    auto Kernel = GlobalEnv::the()->Object()->const_fetch("Kernel"_s);
    auto str = Kernel.send(env, "sprintf"_s, std::move(args)).as_string_or_raise(env);
    ::syslog(pri, "%s", str->c_str());
}

Value Syslog_log(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_at_least(env, 2);
    auto pri_val = args.shift(env, true);
    auto pri = IntegerMethods::convert_to_nat_int_t(env, pri_val);
    syslog_write(env, pri, std::move(args));
    return self;
}

#define SYSLOG_LEVEL_METHOD(name, pri)                                \
    Value Syslog_##name(Env *env, Value self, Args &&args, Block *) { \
        args.ensure_argc_at_least(env, 1);                            \
        syslog_write(env, pri, std::move(args));                      \
        return self;                                                  \
    }

SYSLOG_LEVEL_METHOD(emerg, LOG_EMERG)
SYSLOG_LEVEL_METHOD(alert, LOG_ALERT)
SYSLOG_LEVEL_METHOD(crit, LOG_CRIT)
SYSLOG_LEVEL_METHOD(err, LOG_ERR)
SYSLOG_LEVEL_METHOD(warning, LOG_WARNING)
SYSLOG_LEVEL_METHOD(notice, LOG_NOTICE)
SYSLOG_LEVEL_METHOD(info, LOG_INFO)
SYSLOG_LEVEL_METHOD(debug, LOG_DEBUG)

Value Syslog_LOG_MASK(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 1);
    auto pri = IntegerMethods::convert_to_nat_int_t(env, args.at(0));
    return Value::integer(LOG_MASK(pri));
}

Value Syslog_LOG_UPTO(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 1);
    auto pri = IntegerMethods::convert_to_nat_int_t(env, args.at(0));
    return Value::integer(LOG_UPTO(pri));
}

Value Syslog_close(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    if (!syslog_opened)
        env->raise("RuntimeError", "syslog not opened");

    closelog();

    free(syslog_ident);
    syslog_ident = nullptr;
    syslog_options = -1;
    syslog_facility = -1;
    syslog_mask = -1;
    syslog_opened = false;

    return Value::nil();
}

Value Syslog_open(Env *env, Value self, Args &&args, Block *block) {
    args.ensure_argc_between(env, 0, 3);
    {
        std::lock_guard<std::recursive_mutex> lock(syslog_mutex);

        if (syslog_opened)
            env->raise("RuntimeError", "syslog already open");

        Value ident = args.at(0, Value::nil());
        if (ident.is_nil())
            ident = env->global_get("$0"_s);
        auto ident_str = ident.to_str(env);
        syslog_ident = strdup(ident_str->c_str());

        syslog_options = IntegerMethods::convert_to_nat_int_t(env, args.at(1, Value::integer(LOG_PID | LOG_CONS)));
        syslog_facility = IntegerMethods::convert_to_nat_int_t(env, args.at(2, Value::integer(LOG_USER)));

        openlog(syslog_ident, syslog_options, syslog_facility);

        // Snapshot libc's current priority mask. setlogmask(0) sets the mask
        // to 0 and returns the previous value; we then restore it. This is
        // MRI's idiom for atomically reading the existing mask.
        syslog_mask = setlogmask(0);
        setlogmask(syslog_mask);

        syslog_opened = true;
    }

    if (block) {
        // Catch-all (not just ExceptionObject*) so that non-exception flow
        // control like `throw`/`catch` (ThrowCatchException) also closes the
        // log on the way out.
        try {
            block->run(env, { self }, nullptr);
        } catch (...) {
            std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
            if (syslog_opened)
                Syslog_close(env, self, {}, nullptr);
            throw;
        }
        Syslog_close(env, self, {}, nullptr);
    }

    return self;
}

Value Syslog_reopen(Env *env, Value self, Args &&args, Block *block) {
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    Syslog_close(env, self, {}, nullptr);
    return Syslog_open(env, self, std::move(args), block);
}

Value Syslog_opened(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    return bool_object(syslog_opened);
}

Value Syslog_ident(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    if (!syslog_opened)
        return Value::nil();
    return StringObject::create(syslog_ident);
}

Value Syslog_options(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    if (!syslog_opened)
        return Value::nil();
    return Value::integer(syslog_options);
}

Value Syslog_facility(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    if (!syslog_opened)
        return Value::nil();
    return Value::integer(syslog_facility);
}

Value Syslog_mask(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    if (!syslog_opened)
        return Value::nil();
    return Value::integer(syslog_mask);
}

Value Syslog_set_mask(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 1);
    auto mask = args.at(0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    if (!syslog_opened)
        env->raise("RuntimeError", "must open syslog before setting log mask");
    syslog_mask = IntegerMethods::convert_to_nat_int_t(env, mask);
    setlogmask(syslog_mask);
    return mask;
}

Value Syslog_instance(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    return self;
}

Value Syslog_inspect(Env *env, Value self, Args &&args, Block *) {
    args.ensure_argc_is(env, 0);
    std::lock_guard<std::recursive_mutex> lock(syslog_mutex);
    auto name = self.as_module()->inspect_module();
    if (!syslog_opened)
        return StringObject::create(TM::String::format("<#{}: opened=false>", name));
    return StringObject::create(TM::String::format(
        "<#{}: opened=true, ident=\"{}\", options={}, facility={}, mask={}>",
        name, syslog_ident, syslog_options, syslog_facility, syslog_mask));
}
