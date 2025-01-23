#include "natalie.hpp"

namespace Natalie {

namespace {

    class Finalizer : public Cell {
    public:
        Finalizer(Env *env, Value value)
            : m_env { new Env { env } }
            , m_value { value } {}

        Finalizer(const Finalizer &) = default;
        Finalizer(Finalizer &&) = default;
        Finalizer &operator=(const Finalizer &) = default;
        Finalizer &operator=(Finalizer &&) = default;
        ~Finalizer() = default;

        void run(const nat_int_t object_id) {
            static const auto call = "call"_s;
            if (m_value->type() == ObjectType::Collected) {
                fprintf(stderr, "ERROR: trying GCd object %lli\n", object_id);
            } else {
                m_value->send(m_env, call, { Value::integer(object_id) });
            }
            if (m_next)
                m_next->run(object_id);
        }

        void append(Env *env, Value value) {
            static const auto eql_p = "eql?"_s;
            if (value->send(env, eql_p, { m_value })->is_truthy())
                return;
            if (m_next) {
                m_next->append(env, value);
            } else {
                m_next = new Finalizer { env, value };
            }
        }

        virtual void visit_children(Visitor &visitor) const override {
            visitor.visit(m_env);
            visitor.visit(m_value);
            visitor.visit(m_next);
        }

    private:
        Env *m_env { nullptr };
        Value m_value { nullptr };
        Finalizer *m_next { nullptr };
    };

    // key is object_id, we do *not* want the GC to count key objects
    TM::Hashmap<nat_int_t, Finalizer *> finalizers {};

}

ArrayObject *ObjectSpaceModule::define_finalizer(Env *env, Value obj, Value aProc, Block *block) {
    if (obj.is_integer() || obj->is_float() || obj->is_nil() || obj->is_true() || obj->is_false() || obj->is_symbol())
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
    auto current = finalizers.get(obj.object_id());
    if (current) {
        current->append(env, aProc);
    } else {
        finalizers.put(obj.object_id(), new Finalizer { env, aProc });
    }
    return new ArrayObject { Value::integer(0), aProc };
}

void ObjectSpaceModule::run_single_finalizer(nat_int_t object_id) {
    auto result = finalizers.remove(object_id);
    if (result) {
        result->run(object_id);
        delete(result);
    }
}

void ObjectSpaceModule::shutdown() {
    for (auto pair : finalizers) {
        pair.second->run(pair.first);
        delete(pair.second);
        pair.second = nullptr;
    }

    finalizers.clear();
}

void ObjectSpaceModule::visit_children(Visitor &visitor) const {
    for (auto pair : finalizers)
        visitor.visit(pair.second);
}

}
