#pragma once

#include "natalie/forward.hpp"
#include "natalie/object.hpp"

namespace Natalie {

class ObjectSpaceModule : public Cell {
public:
    static ArrayObject *define_finalizer(Env *, Value, Value = nullptr, Block * = nullptr);

    static void run_single_finalizer(nat_int_t);
    static void shutdown(Env *);

    virtual void visit_children(Visitor &) const override final;
};

}
