#include "natalie.hpp"

namespace Natalie {

void GlobalVariableInfo::set_object(Env *env, Value value) {
    if (m_write_hook) {
        m_value = m_write_hook(env, value, *this);
    } else {
        m_value = value;
    }
}

Optional<Value> GlobalVariableInfo::object(Env *env) {
    if (m_read_hook) {
        auto result = m_read_hook(env, *this);
        if (result)
            return result;
        return Optional<Value> {};
    }
    return m_value;
}

void GlobalVariableInfo::visit_children(Visitor &visitor) const {
    if (m_value)
        visitor.visit(m_value.value());
}

}
