#include "natalie.hpp"

namespace Natalie {

ArrayObject *ObjectSpaceModule::define_finalizer(Env *env, Value obj, Value aProc, Block *block) {
    return new ArrayObject;
}

}
