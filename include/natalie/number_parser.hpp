#pragma once

#include "natalie/forward.hpp"
#include "tm/non_null_ptr.hpp"

namespace Natalie {

class NumberParser {
public:
    static FloatObject *string_to_f(TM::NonNullPtr<const StringObject> str);
    static Value kernel_float(Env *env, Value str, bool exception);
};

}
