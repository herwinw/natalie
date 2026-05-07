#include "natalie.hpp"

namespace Natalie::Thread {

Value MutexObject::lock(Env *env, bool interruptible) {
    auto locked = m_mutex.try_lock();

    if (!locked) {
        if (ThreadObject::current() == m_thread) {
            env->raise("ThreadError", "deadlock; recursive locking");
        } else {
            Defer done_sleeping([] { ThreadObject::set_current_sleeping(false); });
            ThreadObject::set_current_sleeping(true);
            struct timespec request = { 0, 100000 };
            while (!m_mutex.try_lock()) {
                // Mutex#lock is a blocking primitive; deliver :on_blocking
                // interrupts here in addition to :immediate. Skip when the
                // caller asked for an uninterruptible re-acquisition -- the
                // exception path in Mutex#sleep needs to re-take the mutex
                // without raising a second exception while another is already
                // unwinding (which would call std::terminate).
                if (interruptible)
                    ThreadObject::deliver_current_pending(env, ThreadObject::CheckpointKind::Blocking);
                nanosleep(&request, nullptr);
            }
        }
    }

    record_owner();
    return this;
}

Value MutexObject::sleep(Env *env, Optional<Value> timeout_arg) {
    // Re-acquire the mutex uninterruptibly on both exception and normal
    // paths, then explicitly deliver any queued interrupts afterward. The
    // Defer handles the exception path; the explicit lock+deliver handles
    // the normal-return path. is_owned() guards against running the Defer's
    // lock when we already locked explicitly. The post-lock deliver is what
    // actually surfaces a Thread#raise that landed during the wait -- doing
    // it after the lock means the exception unwinds with the mutex held, so
    // ensure blocks that touch shared state see consistent invariants.
    if (!timeout_arg || timeout_arg->is_nil()) {
        Defer reacquire([this, env] { if (!is_owned()) lock(env, false); });
        ThreadObject::current()->sleep(env, -1.0, this);
        lock(env, false);
        ThreadObject::deliver_current_pending(env, ThreadObject::CheckpointKind::Blocking);
        return this;
    }

    auto timeout = timeout_arg.value();

    if ((timeout.is_float() && timeout.as_float()->is_negative()) || (timeout.is_integer() && timeout.integer().is_negative()))
        env->raise("ArgumentError", "time interval must not be negative");

    auto timeout_int = IntegerMethods::convert_to_nat_int_t(env, timeout);

    if (timeout_int < 0)
        env->raise("ArgumentError", "timeout must be positive");

    const auto timeout_float = timeout.is_float() ? static_cast<float>(timeout.as_float()->to_double()) : static_cast<float>(timeout_int);
    Defer reacquire([this, env] { if (!is_owned()) lock(env, false); });
    ThreadObject::current()->sleep(env, timeout_float, this);
    lock(env, false);
    ThreadObject::deliver_current_pending(env, ThreadObject::CheckpointKind::Blocking);

    return Value::integer(timeout_int);
}

Value MutexObject::synchronize(Env *env, Block *block) {
    lock(env);
    Defer done_with_synchronization([this, &env] { if (is_owned()) unlock(env); });
    // Surface any queued Thread#raise before running the body. Without this,
    // an async raise that landed while the caller wasn't in a blocking
    // primitive could miss every checkpoint along the way (e.g. when the next
    // queue.pop returns immediately because the queue is non-empty).
    // NonBlocking kind so :on_blocking-masked interrupts still defer here.
    ThreadObject::deliver_current_pending(env, ThreadObject::CheckpointKind::NonBlocking);
    return block->run(env, {}, nullptr);
}

bool MutexObject::try_lock() {
    if (!m_mutex.try_lock())
        return false;

    record_owner();
    return true;
}

void MutexObject::record_owner() {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);
    m_thread = ThreadObject::current();
    m_thread->add_mutex(this);
    m_fiber = FiberObject::current();
}

Value MutexObject::unlock(Env *env) {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    if (!is_locked())
        env->raise("ThreadError", "Attempt to unlock a mutex which is not locked");

    if (m_thread && m_thread->status(env).is_falsey())
        env->raise("ThreadError", "Attempt to unlock a mutex which is not locked");

    if (m_thread && m_thread != ThreadObject::current())
        env->raise("ThreadError", "Attempt to unlock a mutex which is locked by another thread/fiber");

    m_mutex.unlock();
    assert(m_thread);
    m_thread->remove_mutex(this);
    m_thread = nullptr;
    m_fiber = nullptr;
    return this;
}

bool MutexObject::is_locked() {
    auto now_locked = m_mutex.try_lock();
    if (now_locked) {
        m_mutex.unlock();
        return false;
    }

    return true;
}

bool MutexObject::is_owned() {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    if (!is_locked()) return false;

    if (m_thread != ThreadObject::current())
        return false;

    if (m_fiber != FiberObject::current())
        return false;

    return true;
}

void MutexObject::visit_children(Visitor &visitor) const {
    Object::visit_children(visitor);
    visitor.visit(m_thread);
    visitor.visit(m_fiber);
}

}
