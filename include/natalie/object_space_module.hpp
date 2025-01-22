#pragma once

#include "natalie/forward.hpp"
#include "natalie/object.hpp"

namespace Natalie {

class ObjectSpaceModule {
public:
    static ArrayObject *define_finalizer(Env *, Value, Value = nullptr, Block * = nullptr);
};

}
