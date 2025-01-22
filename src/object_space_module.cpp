#include "natalie.hpp"

namespace Natalie {

ArrayObject *ObjectSpaceModule::define_finalizer(Env *env, Value obj, Value aProc, Block *block) {
    if (!aProc && !block)
        env->raise("ArgumentError", "tried to create Proc object without a block");
    static const auto call = "call"_s;
    if (aProc && !aProc->respond_to(env, call))
        env->raise("ArgumentError", "wrong type argument {} (should be callable)", aProc->klass()->inspect_str());
    return new ArrayObject;
}

}
