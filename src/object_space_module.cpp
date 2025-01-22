#include "natalie.hpp"

namespace Natalie {

namespace {

    // key is object_id, we do *not* want the GC to count key objects
    TM::Hashmap<nat_int_t, Value> finalizers {};

}

ArrayObject *ObjectSpaceModule::define_finalizer(Env *env, Value obj, Value aProc, Block *block) {
    if (obj.is_integer() || obj->is_float() || obj->is_nil() || obj->is_true() || obj->is_false())
        env->raise("ArgumentError", "cannot define finalizer for {}", obj->klass()->inspect_str());
    if (obj->is_frozen())
        env->raise("FrozenError", "can't modify frozen {}: {}", obj->klass()->inspect_str(), obj->inspect_str(env));
    if (!aProc && !block)
        env->raise("ArgumentError", "tried to create Proc object without a block");
    static const auto call = "call"_s;
    if (aProc && !aProc->respond_to(env, call))
        env->raise("ArgumentError", "wrong type argument {} (should be callable)", aProc->klass()->inspect_str());
    if (!aProc)
        aProc = new ProcObject { block };
    return new ArrayObject { Value::integer(0), aProc };
}

void ObjectSpaceModule::run_single_finalizer(nat_int_t object_id) {
    auto result = finalizers.remove(object_id);
    if (result) {
        static const auto call = "call"_s;
        auto env = GlobalEnv::the()->main_env();
        result->send(env, call, { Value::integer(object_id) });
    }
}

void ObjectSpaceModule::shutdown(Env *env) {
    static const auto call = "call"_s;
    for (auto pair : finalizers)
        pair.second->send(env, call, { Value::integer(pair.first) });

    // Remove all the finalizers, we do not want to run them a second time
    finalizers.clear();
}

void ObjectSpaceModule::visit_children(Visitor &visitor) const {
    for (auto pair : finalizers)
        visitor.visit(pair.second);
}

}
