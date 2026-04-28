#include "natalie.hpp"
#include <syslog.h>

using namespace Natalie;

Value init_syslog(Env *env, Value self) {
    return Value::nil();
}

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
