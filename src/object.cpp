#include "natalie.hpp"
#include "natalie/forward.hpp"
#include <cctype>

namespace Natalie {

Object::Object(const Object &other)
    : m_klass { other.m_klass }
    , m_type { other.m_type }
    , m_singleton_class { nullptr } {
    if (other.m_ivars)
        m_ivars = new TM::Hashmap<SymbolObject *, Value> { *other.m_ivars };
}

Value Object::create(Env *env, ClassObject *klass) {
    if (klass->is_singleton())
        env->raise("TypeError", "can't create instance of singleton class");

    Value obj;

    switch (klass->object_type()) {
    case Object::Type::EnumeratorArithmeticSequence:
        obj = new Enumerator::ArithmeticSequenceObject { klass };
        break;

    case Object::Type::Array:
        obj = new ArrayObject {};
        obj->m_klass = klass;
        break;

    case Object::Type::Class:
        obj = new ClassObject { klass };
        break;

    case Object::Type::Complex:
        obj = new ComplexObject { klass };
        break;

    case Object::Type::Dir:
        obj = new DirObject { klass };
        break;

    case Object::Type::Enumerator:
        obj = new Object { klass };
        break;

    case Object::Type::Exception:
        obj = new ExceptionObject { klass };
        break;

    case Object::Type::Fiber:
        obj = new FiberObject { klass };
        break;

    case Object::Type::Hash:
        obj = new HashObject { klass };
        break;

    case Object::Type::Io:
        obj = new IoObject { klass };
        break;

    case Object::Type::File:
        obj = new FileObject { klass };
        break;

    case Object::Type::MatchData:
        obj = new MatchDataObject { klass };
        break;

    case Object::Type::Module:
        obj = new ModuleObject { klass };
        break;

    case Object::Type::Object:
        obj = new Object { klass };
        break;

    case Object::Type::Proc:
        obj = new ProcObject { klass };
        break;

    case Object::Type::Random:
        obj = new RandomObject { klass };
        break;

    case Object::Type::Range:
        obj = new RangeObject { klass };
        break;

    case Object::Type::Regexp:
        obj = new RegexpObject { klass };
        break;

    case Object::Type::String:
        obj = new StringObject { klass };
        break;

    case Object::Type::Thread:
        obj = new ThreadObject { klass };
        break;

    case Object::Type::ThreadBacktraceLocation:
        obj = new Thread::Backtrace::LocationObject { klass };
        break;

    case Object::Type::ThreadGroup:
        obj = new ThreadGroupObject { klass };
        break;

    case Object::Type::ThreadMutex:
        obj = new Thread::MutexObject { klass };
        break;

    case Object::Type::Time:
        obj = new TimeObject { klass };
        break;

    case Object::Type::VoidP:
        obj = new VoidPObject { klass };
        break;

    case Object::Type::FileStat:
        obj = new FileStatObject { klass };
        break;

    case Object::Type::Binding:
    case Object::Type::Encoding:
    case Object::Type::Env:
    case Object::Type::False:
    case Object::Type::Float:
    case Object::Type::Method:
    case Object::Type::Nil:
    case Object::Type::Rational:
    case Object::Type::Symbol:
    case Object::Type::True:
    case Object::Type::UnboundMethod:
        obj = nullptr;
        break;

    case Object::Type::Collected:
        NAT_UNREACHABLE();
    }

    return obj;
}

Value Object::_new(Env *env, Value klass_value, Args &&args, Block *block) {
    Value obj = create(env, klass_value->as_class());
    if (!obj)
        NAT_UNREACHABLE();

    obj.send(env, "initialize"_s, std::move(args), block);
    return obj;
}

Value Object::allocate(Env *env, Value klass_value, Args &&args, Block *block) {
    args.ensure_argc_is(env, 0);

    ClassObject *klass = klass_value->as_class();
    if (!klass->respond_to(env, "allocate"_s))
        env->raise("TypeError", "calling {}.allocate is prohibited", klass->inspect_str());

    Value obj;
    switch (klass->object_type()) {
    case Object::Type::Proc:
    case Object::Type::EnumeratorArithmeticSequence:
        obj = nullptr;
        break;

    default:
        obj = create(env, klass);
        break;
    }

    if (!obj)
        env->raise("TypeError", "allocator undefined for {}", klass->inspect_str());

    return obj;
}

Value Object::initialize(Env *env, Value self) {
    return NilObject::the();
}

NilObject *Object::as_nil() {
    assert(m_type == Type::Nil);
    return static_cast<NilObject *>(this);
}

const NilObject *Object::as_nil() const {
    assert(m_type == Type::Nil);
    return static_cast<const NilObject *>(this);
}

Enumerator::ArithmeticSequenceObject *Object::as_enumerator_arithmetic_sequence() {
    assert(m_type == Type::EnumeratorArithmeticSequence);
    return static_cast<Enumerator::ArithmeticSequenceObject *>(this);
}

ArrayObject *Object::as_array() {
    assert(m_type == Type::Array);
    return static_cast<ArrayObject *>(this);
}

const ArrayObject *Object::as_array() const {
    assert(m_type == Type::Array);
    return static_cast<const ArrayObject *>(this);
}

BindingObject *Object::as_binding() {
    assert(m_type == Type::Binding);
    return static_cast<BindingObject *>(this);
}

const BindingObject *Object::as_binding() const {
    assert(m_type == Type::Binding);
    return static_cast<const BindingObject *>(this);
}

MethodObject *Object::as_method() {
    assert(m_type == Type::Method);
    return static_cast<MethodObject *>(this);
}

const MethodObject *Object::as_method() const {
    assert(m_type == Type::Method);
    return static_cast<const MethodObject *>(this);
}

ModuleObject *Object::as_module() {
    assert(m_type == Type::Module || m_type == Type::Class);
    return static_cast<ModuleObject *>(this);
}

const ModuleObject *Object::as_module() const {
    assert(m_type == Type::Module);
    return static_cast<const ModuleObject *>(this);
}

ClassObject *Object::as_class() {
    assert(m_type == Type::Class);
    return static_cast<ClassObject *>(this);
}

const ClassObject *Object::as_class() const {
    assert(m_type == Type::Class);
    return static_cast<const ClassObject *>(this);
}

ComplexObject *Object::as_complex() {
    assert(m_type == Type::Complex);
    return static_cast<ComplexObject *>(this);
}

const ComplexObject *Object::as_complex() const {
    assert(m_type == Type::Complex);
    return static_cast<const ComplexObject *>(this);
}

DirObject *Object::as_dir() {
    assert(m_type == Type::Dir);
    return static_cast<DirObject *>(this);
}

const DirObject *Object::as_dir() const {
    assert(m_type == Type::Dir);
    return static_cast<const DirObject *>(this);
}

EncodingObject *Object::as_encoding() {
    assert(m_type == Type::Encoding);
    return static_cast<EncodingObject *>(this);
}

const EncodingObject *Object::as_encoding() const {
    assert(m_type == Type::Encoding);
    return static_cast<const EncodingObject *>(this);
}

EnvObject *Object::as_env() {
    assert(m_type == Type::Env);
    return static_cast<EnvObject *>(this);
}

const EnvObject *Object::as_env() const {
    assert(m_type == Type::Env);
    return static_cast<const EnvObject *>(this);
}

ExceptionObject *Object::as_exception() {
    assert(m_type == Type::Exception);
    return static_cast<ExceptionObject *>(this);
}

const ExceptionObject *Object::as_exception() const {
    assert(m_type == Type::Exception);
    return static_cast<const ExceptionObject *>(this);
}

FalseObject *Object::as_false() {
    assert(m_type == Type::False);
    return static_cast<FalseObject *>(this);
}

const FalseObject *Object::as_false() const {
    assert(m_type == Type::False);
    return static_cast<const FalseObject *>(this);
}

FiberObject *Object::as_fiber() {
    assert(m_type == Type::Fiber);
    return static_cast<FiberObject *>(this);
}

const FiberObject *Object::as_fiber() const {
    assert(m_type == Type::Fiber);
    return static_cast<const FiberObject *>(this);
}

FloatObject *Object::as_float() {
    assert(m_type == Type::Float);
    return static_cast<FloatObject *>(this);
}

const FloatObject *Object::as_float() const {
    assert(m_type == Type::Float);
    return static_cast<const FloatObject *>(this);
}

HashObject *Object::as_hash() {
    assert(m_type == Type::Hash);
    return static_cast<HashObject *>(this);
}

const HashObject *Object::as_hash() const {
    assert(m_type == Type::Hash);
    return static_cast<const HashObject *>(this);
}

IoObject *Object::as_io() {
    assert(m_type == Type::Io || m_type == Type::File);
    return static_cast<IoObject *>(this);
}

const IoObject *Object::as_io() const {
    assert(m_type == Type::Io);
    return static_cast<const IoObject *>(this);
}

FileObject *Object::as_file() {
    assert(m_type == Type::File);
    return static_cast<FileObject *>(this);
}

const FileObject *Object::as_file() const {
    assert(m_type == Type::File);
    return static_cast<const FileObject *>(this);
}

FileStatObject *Object::as_file_stat() {
    assert(m_type == Type::FileStat);
    return static_cast<FileStatObject *>(this);
}

const FileStatObject *Object::as_file_stat() const {
    assert(m_type == Type::FileStat);
    return static_cast<const FileStatObject *>(this);
}

MatchDataObject *Object::as_match_data() {
    assert(m_type == Type::MatchData);
    return static_cast<MatchDataObject *>(this);
}

const MatchDataObject *Object::as_match_data() const {
    assert(m_type == Type::MatchData);
    return static_cast<const MatchDataObject *>(this);
}

ProcObject *Object::as_proc() {
    assert(m_type == Type::Proc);
    return static_cast<ProcObject *>(this);
}

const ProcObject *Object::as_proc() const {
    assert(m_type == Type::Proc);
    return static_cast<const ProcObject *>(this);
}

RandomObject *Object::as_random() {
    assert(m_type == Type::Random);
    return static_cast<RandomObject *>(this);
}

const RandomObject *Object::as_random() const {
    assert(m_type == Type::Random);
    return static_cast<const RandomObject *>(this);
}

RangeObject *Object::as_range() {
    assert(m_type == Type::Range);
    return static_cast<RangeObject *>(this);
}

const RangeObject *Object::as_range() const {
    assert(m_type == Type::Range);
    return static_cast<const RangeObject *>(this);
}

RationalObject *Object::as_rational() {
    assert(m_type == Type::Rational);
    return static_cast<RationalObject *>(this);
}

const RationalObject *Object::as_rational() const {
    assert(m_type == Type::Rational);
    return static_cast<const RationalObject *>(this);
}

RegexpObject *Object::as_regexp() {
    assert(m_type == Type::Regexp);
    return static_cast<RegexpObject *>(this);
}

const RegexpObject *Object::as_regexp() const {
    assert(m_type == Type::Regexp);
    return static_cast<const RegexpObject *>(this);
}

StringObject *Object::as_string() {
    assert(m_type == Type::String);
    return static_cast<StringObject *>(this);
}

const StringObject *Object::as_string() const {
    assert(m_type == Type::String);
    return static_cast<const StringObject *>(this);
}

SymbolObject *Object::as_symbol() {
    assert(m_type == Type::Symbol);
    return static_cast<SymbolObject *>(this);
}

const SymbolObject *Object::as_symbol() const {
    assert(m_type == Type::Symbol);
    return static_cast<const SymbolObject *>(this);
}

ThreadObject *Object::as_thread() {
    assert(m_type == Type::Thread);
    return static_cast<ThreadObject *>(this);
}

const ThreadObject *Object::as_thread() const {
    assert(m_type == Type::Thread);
    return static_cast<const ThreadObject *>(this);
}

Thread::Backtrace::LocationObject *Object::as_thread_backtrace_location() {
    assert(m_type == Type::ThreadBacktraceLocation);
    return static_cast<Thread::Backtrace::LocationObject *>(this);
}

const Thread::Backtrace::LocationObject *Object::as_thread_backtrace_location() const {
    assert(m_type == Type::ThreadBacktraceLocation);
    return static_cast<const Thread::Backtrace::LocationObject *>(this);
}

ThreadGroupObject *Object::as_thread_group() {
    assert(m_type == Type::ThreadGroup);
    return static_cast<ThreadGroupObject *>(this);
}

const ThreadGroupObject *Object::as_thread_group() const {
    assert(m_type == Type::ThreadGroup);
    return static_cast<const ThreadGroupObject *>(this);
}

Thread::MutexObject *Object::as_thread_mutex() {
    assert(m_type == Type::ThreadMutex);
    return static_cast<Thread::MutexObject *>(this);
}

const Thread::MutexObject *Object::as_thread_mutex() const {
    assert(m_type == Type::ThreadMutex);
    return static_cast<const Thread::MutexObject *>(this);
}

TimeObject *Object::as_time() {
    assert(m_type == Type::Time);
    return static_cast<TimeObject *>(this);
}

const TimeObject *Object::as_time() const {
    assert(m_type == Type::Time);
    return static_cast<const TimeObject *>(this);
}

TrueObject *Object::as_true() {
    assert(m_type == Type::True);
    return static_cast<TrueObject *>(this);
}

const TrueObject *Object::as_true() const {
    assert(m_type == Type::True);
    return static_cast<const TrueObject *>(this);
}

UnboundMethodObject *Object::as_unbound_method() {
    assert(m_type == Type::UnboundMethod);
    return static_cast<UnboundMethodObject *>(this);
}

const UnboundMethodObject *Object::as_unbound_method() const {
    assert(m_type == Type::UnboundMethod);
    return static_cast<const UnboundMethodObject *>(this);
}

VoidPObject *Object::as_void_p() {
    assert(m_type == Type::VoidP);
    return static_cast<VoidPObject *>(this);
}

const VoidPObject *Object::as_void_p() const {
    assert(m_type == Type::VoidP);
    return static_cast<const VoidPObject *>(this);
}

ArrayObject *Object::as_array_or_raise(Env *env) {
    if (m_type != Type::Array)
        env->raise("TypeError", "{} can't be coerced into Array", m_klass->inspect_str());
    return static_cast<ArrayObject *>(this);
}

ClassObject *Object::as_class_or_raise(Env *env) {
    if (m_type != Type::Class)
        env->raise("TypeError", "{} can't be coerced into Class", m_klass->inspect_str());
    return static_cast<ClassObject *>(this);
}

ComplexObject *Object::as_complex_or_raise(Env *env) {
    if (m_type != Type::Complex)
        env->raise("TypeError", "{} can't be coerced into Complex", m_klass->inspect_str());
    return static_cast<ComplexObject *>(this);
}

EncodingObject *Object::as_encoding_or_raise(Env *env) {
    if (m_type != Type::Encoding)
        env->raise("TypeError", "{} can't be coerced into Encoding", m_klass->inspect_str());
    return static_cast<EncodingObject *>(this);
}

ExceptionObject *Object::as_exception_or_raise(Env *env) {
    if (m_type != Type::Exception)
        env->raise("TypeError", "{} can't be coerced into Exception", m_klass->inspect_str());
    return static_cast<ExceptionObject *>(this);
}

FloatObject *Object::as_float_or_raise(Env *env) {
    if (m_type != Type::Float)
        env->raise("TypeError", "{} can't be coerced into Float", m_klass->inspect_str());
    return static_cast<FloatObject *>(this);
}

HashObject *Object::as_hash_or_raise(Env *env) {
    if (m_type != Type::Hash)
        env->raise("TypeError", "{} can't be coerced into Hash", m_klass->inspect_str());
    return static_cast<HashObject *>(this);
}

MatchDataObject *Object::as_match_data_or_raise(Env *env) {
    if (m_type != Type::MatchData)
        env->raise("TypeError", "{} can't be coerced into MatchData", m_klass->inspect_str());
    return static_cast<MatchDataObject *>(this);
}

ModuleObject *Object::as_module_or_raise(Env *env) {
    if (m_type != Type::Module && m_type != Type::Class)
        env->raise("TypeError", "{} can't be coerced into Module", m_klass->inspect_str());
    return static_cast<ModuleObject *>(this);
}

RangeObject *Object::as_range_or_raise(Env *env) {
    if (m_type != Type::Range)
        env->raise("TypeError", "{} can't be coerced into Range", m_klass->inspect_str());
    return static_cast<RangeObject *>(this);
}

StringObject *Object::as_string_or_raise(Env *env) {
    if (m_type != Type::String)
        env->raise("TypeError", "{} can't be coerced into String", m_klass->inspect_str());
    return static_cast<StringObject *>(this);
}

SymbolObject *Object::to_instance_variable_name(Env *env, Value name) {
    SymbolObject *symbol = name.to_symbol(env, Value::Conversion::Strict); // TypeError if not Symbol/String

    if (!symbol->is_ivar_name()) {
        if (name.is_string()) {
            env->raise_name_error(name->as_string(), "`{}' is not allowed as an instance variable name", symbol->string());
        } else {
            env->raise_name_error(symbol, "`{}' is not allowed as an instance variable name", symbol->string());
        }
    }

    return symbol;
}

void Object::set_singleton_class(ClassObject *klass) {
    klass->set_is_singleton(true);
    m_singleton_class = klass;
}

ClassObject *Object::singleton_class(Env *env, Value self) {
    if (self.is_integer() || self.is_float() || self.is_symbol())
        env->raise("TypeError", "can't define singleton");

    if (self->m_singleton_class)
        return self->m_singleton_class;

    String name;
    if (self.is_module()) {
        name = String::format("#<Class:{}>", self->as_module()->inspect_str());
    } else if (self.respond_to(env, "inspect"_s)) {
        name = String::format("#<Class:{}>", self.inspect_str(env));
    }

    ClassObject *singleton_superclass;
    if (self.is_class()) {
        singleton_superclass = singleton_class(env, self->as_class()->superclass(env));
    } else {
        singleton_superclass = self->m_klass;
    }
    auto new_singleton_class = new ClassObject { singleton_superclass };
    if (self->is_frozen()) new_singleton_class->freeze();
    singleton_superclass->initialize_subclass_without_checks(new_singleton_class, env, name);
    self->set_singleton_class(new_singleton_class);
    if (self->is_frozen()) self->m_singleton_class->freeze();
    if (self.is_string() && self->as_string()->is_chilled()) {
        if (self->as_string()->chilled() == StringObject::Chilled::String) {
            env->deprecation_warn("literal string will be frozen in the future");
        } else {
            env->deprecation_warn("string returned by :{}.to_s will be frozen in the future", self->as_string()->string());
        }
    }
    return self->m_singleton_class;
}

ClassObject *Object::subclass(Env *env, Value superclass, const char *name) {
    if (!superclass.is_class())
        env->raise("TypeError", "superclass must be an instance of Class (given an instance of {})", superclass.klass()->inspect_str());
    return superclass->as_class()->subclass(env, name);
}

void Object::extend_once(Env *env, ModuleObject *module) {
    singleton_class(env, this)->include_once(env, module);
}

Value Object::const_find_with_autoload(Env *env, Value ns, Value self, SymbolObject *name, ConstLookupSearchMode search_mode, ConstLookupFailureMode failure_mode) {
    if (GlobalEnv::the()->instance_evaling()) {
        auto context = GlobalEnv::the()->current_instance_eval_context();
        if (context.caller_env->module()) {
            // We want to search the constant in the context in which instance_eval was called
            return context.caller_env->module()->const_find_with_autoload(env, self, name, search_mode, failure_mode);
        }
    }

    if (ns.is_module())
        return ns->as_module()->const_find_with_autoload(env, self, name, search_mode, failure_mode);

    if (ns.is_integer())
        return GlobalEnv::the()->Integer()->const_find_with_autoload(env, self, name, search_mode, failure_mode);

    return ns->m_klass->const_find_with_autoload(env, self, name, search_mode, failure_mode);
}

Value Object::const_fetch(Value ns, SymbolObject *name) {
    if (ns.is_module())
        return ns->as_module()->const_fetch(name);

    return ns.klass()->const_fetch(name);
}

Value Object::const_set(Env *env, Value ns, SymbolObject *name, Value val) {
    if (ns.is_module())
        return ns->as_module()->const_set(name, val);
    else if (ns == GlobalEnv::the()->main_obj())
        return GlobalEnv::the()->Object()->const_set(name, val);
    else
        env->raise("TypeError", "{} is not a class/module", ns.inspect_str(env));
}

Value Object::const_set(Env *env, Value ns, SymbolObject *name, MethodFnPtr autoload_fn, StringObject *autoload_path) {
    if (ns.is_module())
        return ns->as_module()->const_set(name, autoload_fn, autoload_path);
    else if (ns == GlobalEnv::the()->main_obj())
        return GlobalEnv::the()->Object()->const_set(name, autoload_fn, autoload_path);
    else
        env->raise("TypeError", "{} is not a class/module", ns.inspect_str(env));
}

bool Object::ivar_defined(Env *env, Value self, SymbolObject *name) {
    if (self.is_integer() || self.is_float())
        return false;
    return self->ivar_defined(env, name);
}

Value Object::ivar_get(Env *env, Value self, SymbolObject *name) {
    if (self.is_integer() || self.is_float())
        return NilObject::the();
    return self->ivar_get(env, name);
}

Value Object::ivar_set(Env *env, Value self, SymbolObject *name, Value val) {
    self.assert_not_frozen(env);
    return self->ivar_set(env, name, val);
}

bool Object::ivar_defined(Env *env, SymbolObject *name) {
    if (!name->is_ivar_name())
        env->raise_name_error(name, "`{}' is not allowed as an instance variable name", name->string());

    if (!m_ivars)
        return false;

    auto val = m_ivars->get(name, env);
    if (val)
        return true;
    else
        return false;
}

Value Object::ivar_get(Env *env, SymbolObject *name) {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    if (!name->is_ivar_name())
        env->raise_name_error(name, "`{}' is not allowed as an instance variable name", name->string());

    if (!m_ivars)
        return NilObject::the();

    auto val = m_ivars->get(name, env);
    if (val)
        return val;
    else
        return NilObject::the();
}

Value Object::ivar_remove(Env *env, SymbolObject *name) {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    if (!name->is_ivar_name())
        env->raise("NameError", "`{}' is not allowed as an instance variable name", name->string());

    if (!m_ivars)
        env->raise("NameError", "instance variable {} not defined", name->string());

    auto val = m_ivars->remove(name, env);
    if (val)
        return val;
    else
        env->raise("NameError", "instance variable {} not defined", name->string());
}

Value Object::ivar_set(Env *env, SymbolObject *name, Value val) {
    NAT_GC_GUARD_VALUE(val);
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    assert_not_frozen(env);

    if (!name->is_ivar_name())
        env->raise_name_error(name, "`{}' is not allowed as an instance variable name", name->string());

    if (!m_ivars)
        m_ivars = new TM::Hashmap<SymbolObject *, Value> {};

    m_ivars->put(name, val, env);
    return val;
}

Value Object::instance_variables(Env *env) {
    if (m_type == Type::Float || !m_ivars)
        return new ArrayObject;

    ArrayObject *ary = new ArrayObject { m_ivars->size() };
    for (auto pair : *m_ivars)
        ary->push(pair.first);
    return ary;
}

Value Object::cvar_get(Env *env, SymbolObject *name) {
    if (GlobalEnv::the()->instance_evaling()) {
        // Get class variable in block definition scope
        auto context = GlobalEnv::the()->current_instance_eval_context();
        return context.block_original_self->cvar_get_or_raise(env, name);
    }
    return cvar_get_or_raise(env, name);
}

Value Object::cvar_get_or_raise(Env *env, SymbolObject *name) {
    Value val = cvar_get_or_null(env, name);
    if (val) {
        return val;
    } else {
        ModuleObject *module;
        if (m_type == Type::Module || m_type == Type::Class)
            module = as_module();
        else
            module = m_klass;
        env->raise_name_error(name, "uninitialized class variable {} in {}", name->string(), module->inspect_str());
    }
}

Value Object::cvar_get_or_null(Env *env, SymbolObject *name) {
    return m_klass->cvar_get_or_null(env, name);
}

Value Object::cvar_set(Env *env, SymbolObject *name, Value val) {
    return m_klass->cvar_set(env, name, val);
}

void Object::method_alias(Env *env, Value self, Value new_name, Value old_name) {
    new_name.assert_type(env, Type::Symbol, "Symbol");
    old_name.assert_type(env, Type::Symbol, "Symbol");
    method_alias(env, self, new_name->as_symbol(), old_name->as_symbol());
}

void Object::method_alias(Env *env, Value self, SymbolObject *new_name, SymbolObject *old_name) {
    if (self.is_integer())
        env->raise("TypeError", "no klass to make alias");

    if (self.is_symbol())
        env->raise("TypeError", "no klass to make alias");

    if (self->is_main_object()) {
        self.klass()->make_method_alias(env, new_name, old_name);
    } else if (self.is_module()) {
        self->as_module()->method_alias(env, new_name, old_name);
    } else {
        singleton_class(env, self)->make_method_alias(env, new_name, old_name);
    }
}

void Object::singleton_method_alias(Env *env, Value self, SymbolObject *new_name, SymbolObject *old_name) {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    ClassObject *klass = singleton_class(env, self);
    if (klass->is_frozen())
        env->raise("FrozenError", "can't modify frozen object: {}", self.to_s(env)->string());
    klass->method_alias(env, new_name, old_name);
}

SymbolObject *Object::define_singleton_method(Env *env, Value self, SymbolObject *name, MethodFnPtr fn, int arity) {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    ClassObject *klass = singleton_class(env, self)->as_class();
    if (klass->is_frozen())
        env->raise("FrozenError", "can't modify frozen object: {}", self.to_s(env)->string());
    klass->define_method(env, name, fn, arity);
    return name;
}

SymbolObject *Object::define_singleton_method(Env *env, Value self, SymbolObject *name, Block *block) {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    ClassObject *klass = singleton_class(env, self);
    if (klass->is_frozen())
        env->raise("FrozenError", "can't modify frozen object: {}", self.to_s(env)->string());
    klass->define_method(env, name, block);
    return name;
}

SymbolObject *Object::undefine_singleton_method(Env *env, Value self, SymbolObject *name) {
    std::lock_guard<std::recursive_mutex> lock(g_gc_recursive_mutex);

    ClassObject *klass = singleton_class(env, self);
    klass->undefine_method(env, name);
    return name;
}

SymbolObject *Object::define_method(Env *env, Value self, SymbolObject *name, MethodFnPtr fn, int arity) {
    if (self.is_module())
        return self->as_module()->define_method(env, name, fn, arity);

    if (GlobalEnv::the()->instance_evaling())
        return define_singleton_method(env, self, name, fn, arity);

    self.klass()->define_method(env, name, fn, arity);
    return name;
}

SymbolObject *Object::define_method(Env *env, Value self, SymbolObject *name, Block *block) {
    if (self.is_module())
        return self->as_module()->define_method(env, name, block);

    if (GlobalEnv::the()->instance_evaling())
        return define_singleton_method(env, self, name, block);

    self.klass()->define_method(env, name, block);
    return name;
}

SymbolObject *Object::undefine_method(Env *env, Value self, SymbolObject *name) {
    if (self.is_module())
        return self->as_module()->undefine_method(env, name);

    self.klass()->undefine_method(env, name);
    return name;
}

Value Object::main_obj_define_method(Env *env, Value name, Value proc_or_unbound_method, Block *block) {
    return m_klass->define_method(env, name, proc_or_unbound_method, block);
}

Value Object::main_obj_inspect(Env *) {
    return new StringObject { "main" };
}

void Object::private_method(Env *env, SymbolObject *name) {
    private_method(env, Args { name });
}

void Object::protected_method(Env *env, SymbolObject *name) {
    protected_method(env, Args { name });
}

void Object::module_function(Env *env, SymbolObject *name) {
    module_function(env, Args { name });
}

Value Object::private_method(Env *env, Args &&args) {
    if (!is_main_object()) {
        printf("tried to call private_method on something that has no methods\n");
        abort();
    }
    return m_klass->private_method(env, std::move(args));
}

Value Object::protected_method(Env *env, Args &&args) {
    if (!is_main_object()) {
        printf("tried to call protected_method on something that has no methods\n");
        abort();
    }
    return m_klass->protected_method(env, std::move(args));
}

Value Object::module_function(Env *env, Args &&args) {
    printf("tried to call module_function on something that isn't a module\n");
    abort();
}

Value Object::public_send(Env *env, SymbolObject *name, Args &&args, Block *block, Value sent_from) {
    return send(env, name, std::move(args), block, MethodVisibility::Public, sent_from);
}

Value Object::public_send(Env *env, Value self, Args &&args, Block *block) {
    auto name = args.shift().to_symbol(env, Value::Conversion::Strict);
    if (self.is_integer())
        return self.integer_send(env, name, std::move(args), block, nullptr, MethodVisibility::Public);

    return self->public_send(env->caller(), name, std::move(args), block);
}

Value Object::send(Env *env, SymbolObject *name, Args &&args, Block *block, Value sent_from) {
    return send(env, name, std::move(args), block, MethodVisibility::Private, sent_from);
}

Value Object::send(Env *env, Value self, Args &&args, Block *block) {
    auto name = args.shift().to_symbol(env, Value::Conversion::Strict);
    if (self.is_integer())
        return self.integer_send(env, name, std::move(args), block, nullptr, MethodVisibility::Private);

    return self.send(env->caller(), name, std::move(args), block);
}

Value Object::send(Env *env, SymbolObject *name, Args &&args, Block *block, MethodVisibility visibility_at_least, Value sent_from) {
    static const auto initialize = SymbolObject::intern("initialize");
    Method *method = find_method(env, name, visibility_at_least, sent_from);
    // TODO: make a copy if has empty keyword hash (unless that's not rare)
    args.pop_empty_keyword_hash();
    if (method) {
        auto result = method->call(env, this, std::move(args), block);
        if (name == initialize)
            result = this;
        return result;
    } else if (respond_to(env, "method_missing"_s)) {
        return method_missing_send(env, name, std::move(args), block);
    } else {
        env->raise_no_method_error(this, name, GlobalEnv::the()->method_missing_reason());
    }
}

Value Object::method_missing_send(Env *env, SymbolObject *name, Args &&args, Block *block) {
    Vector<Value> new_args(args.size() + 1);
    new_args.push(name);
    for (size_t i = 0; i < args.size(); i++)
        new_args.push(args[i]);
    return send(env, "method_missing"_s, Args(new_args, args.has_keyword_hash()), block);
}

Value Object::method_missing(Env *env, Value self, Args &&args, Block *block) {
    if (args.size() == 0) {
        env->raise("ArgError", "no method name given");
    } else if (!args[0].is_symbol()) {
        env->raise("ArgError", "method name must be a Symbol but {} is given", args[0].klass()->inspect_str());
    } else {
        auto name = args[0]->as_symbol();
        env = env->caller();
        env->raise_no_method_error(self, name, GlobalEnv::the()->method_missing_reason());
    }
}

Method *Object::find_method(Env *env, SymbolObject *method_name, MethodVisibility visibility_at_least, Value sent_from) const {
    ModuleObject *klass = singleton_class();
    if (!klass)
        klass = m_klass;
    assert(klass);
    auto method_info = klass->find_method(env, method_name);

    if (!method_info.is_defined()) {
        // FIXME: store on current thread
        GlobalEnv::the()->set_method_missing_reason(MethodMissingReason::Undefined);
        return nullptr;
    }

    MethodVisibility visibility = method_info.visibility();

    if (visibility >= visibility_at_least)
        return method_info.method();

    if (visibility == MethodVisibility::Protected && sent_from && sent_from.is_a(env, klass))
        return method_info.method();

    switch (visibility) {
    case MethodVisibility::Protected:
        // FIXME: store on current thread
        GlobalEnv::the()->set_method_missing_reason(MethodMissingReason::Protected);
        break;
    case MethodVisibility::Private:
        // FIXME: store on current thread
        GlobalEnv::the()->set_method_missing_reason(MethodMissingReason::Private);
        break;
    default:
        NAT_UNREACHABLE();
    }

    return nullptr;
}

Value Object::duplicate(Env *env) const {
    switch (m_type) {
    case Object::Type::Array:
        return new ArrayObject { *as_array() };
    case Object::Type::Class: {
        auto out = new ClassObject { *as_class() };
        auto s_class = singleton_class();
        if (s_class)
            out->set_singleton_class(s_class->clone(env)->as_class());
        return out;
    }
    case Object::Type::Complex:
        return new ComplexObject { *as_complex() };
    case Object::Type::Exception:
        return new ExceptionObject { *as_exception() };
    case Object::Type::False:
        return FalseObject::the();
    case Object::Type::Float:
        return new FloatObject { *as_float() };
    case Object::Type::Hash:
        return new HashObject { env, *as_hash() };
    case Object::Type::Module:
        return new ModuleObject { *as_module() };
    case Object::Type::Nil:
        return NilObject::the();
    case Object::Type::Object:
        return new Object { *this };
    case Object::Type::Proc:
        return new ProcObject { *as_proc() };
    case Object::Type::Range:
        return new RangeObject { *as_range() };
    case Object::Type::Rational:
        return new RationalObject { *as_rational() };
    case Object::Type::Regexp:
        return new RegexpObject { env, as_regexp()->pattern(), as_regexp()->options() };
    case Object::Type::String:
        return new StringObject { *as_string() };
    case Object::Type::Symbol:
        return SymbolObject::intern(as_symbol()->string());
    case Object::Type::True:
        return TrueObject::the();
    case Object::Type::UnboundMethod:
        return new UnboundMethodObject { *as_unbound_method() };
    case Object::Type::MatchData:
        return new MatchDataObject { *as_match_data() };
    default:
        fprintf(stderr, "I don't know how to dup this kind of object yet %s (type = %d).\n", m_klass->inspect_str().c_str(), static_cast<int>(m_type));
        abort();
    }
}

Value Object::clone(Env *env, Value freeze) {
    bool freeze_bool = true;
    if (freeze) {
        if (freeze.is_false()) {
            freeze_bool = false;
        } else if (!freeze.is_true() && !freeze.is_nil()) {
            env->raise("ArgumentError", "unexpected value for freeze: {}", freeze.klass()->inspect_str());
        }
    }

    auto duplicate = this->duplicate(env);
    if (!duplicate->singleton_class()) {
        auto s_class = singleton_class();
        if (s_class) {
            duplicate->set_singleton_class(s_class->clone(env)->as_class());
        }
    }

    if (freeze) {
        auto keyword_hash = new HashObject {};
        keyword_hash->put(env, "freeze"_s, freeze);
        auto args = Args({ this, keyword_hash }, true);
        duplicate.send(env, "initialize_clone"_s, std::move(args));
    } else {
        duplicate.send(env, "initialize_clone"_s, { this });
    }

    if (freeze_bool && is_frozen())
        duplicate->freeze();
    else if (m_type == Type::String && as_string()->is_chilled())
        duplicate->as_string()->set_chilled(as_string()->chilled());

    return duplicate;
}

Value Object::clone_obj(Env *env, Value self, Value freeze) {
    if (self.is_integer())
        return self;

    return self->clone(env, freeze);
}

void Object::copy_instance_variables(const Value other) {
    assert(other);
    if (m_ivars)
        delete m_ivars;
    if (other.is_integer())
        return;

    auto ivars = other.object()->m_ivars;
    if (ivars)
        m_ivars = new TM::Hashmap<SymbolObject *, Value> { *ivars };
}

const char *Object::defined(Env *env, SymbolObject *name, bool strict) {
    Value obj = nullptr;
    if (name->is_constant_name()) {
        if (strict) {
            if (m_type == Type::Module || m_type == Type::Class)
                obj = as_module()->const_get(name);
        } else {
            obj = m_klass->const_find(env, name, ConstLookupSearchMode::NotStrict, ConstLookupFailureMode::Null);
        }
        if (obj) return "constant";
    } else if (name->is_global_name()) {
        obj = env->global_get(name);
        if (obj != NilObject::the()) return "global-variable";
    } else if (name->is_ivar_name()) {
        obj = ivar_get(env, name);
        if (obj != NilObject::the()) return "instance-variable";
    } else if (respond_to(env, name)) {
        return "method";
    }
    return nullptr;
}

Value Object::defined_obj(Env *env, SymbolObject *name, bool strict) {
    const char *result = defined(env, name, strict);
    if (result) {
        return new StringObject { result };
    } else {
        return NilObject::the();
    }
}

ProcObject *Object::to_proc(Env *env) {
    auto to_proc_symbol = "to_proc"_s;
    if (respond_to(env, to_proc_symbol)) {
        return send(env, to_proc_symbol)->as_proc();
    } else {
        env->raise("TypeError", "wrong argument type {} (expected Proc)", m_klass->inspect_str());
    }
}

void Object::freeze() {
    m_frozen = true;
    if (m_singleton_class) m_singleton_class->freeze();
}

Value Object::instance_eval(Env *env, Value self, Args &&args, Block *block) {
    if (block) {
        args.ensure_argc_is(env, 0);
    }

    if (args.size() > 0 || !block) {
        args.ensure_argc_between(env, 1, 3);
        env->raise("ArgumentError", "Natalie only supports instance_eval with a block");
    }

    GlobalEnv::the()->push_instance_eval_context(env->caller(), block->self());
    block->set_self(self);
    Defer done_instance_evaling([block]() {
        auto context = GlobalEnv::the()->pop_instance_eval_context();
        block->set_self(context.block_original_self);
    });
    Value block_args[] = { self };
    return block->run(env, Args(1, block_args), nullptr);
}

Value Object::instance_exec(Env *env, Value self, Args &&args, Block *block) {
    if (!block)
        env->raise("LocalJumpError", "no block given");

    GlobalEnv::the()->push_instance_eval_context(env->caller(), block->self());
    block->set_self(self);
    Defer done_instance_evaling([block]() {
        auto context = GlobalEnv::the()->pop_instance_eval_context();
        block->set_self(context.block_original_self);
    });

    return block->run(env, std::move(args), nullptr);
}

void Object::assert_not_frozen(Env *env) {
    if (is_frozen()) {
        env->raise("FrozenError", "can't modify frozen {}: {}", klass()->inspect_str(), inspect_str(env));
    } else if (m_type == Type::String && as_string()->is_chilled()) {
        if (as_string()->chilled() == StringObject::Chilled::String) {
            env->deprecation_warn("literal string will be frozen in the future");
        } else {
            env->deprecation_warn("string returned by :{}.to_s will be frozen in the future", as_string()->string());
        }
        as_string()->unset_chilled();
    }
}

void Object::assert_not_frozen(Env *env, Value receiver) {
    if (is_frozen()) {
        auto FrozenError = GlobalEnv::the()->Object()->const_fetch("FrozenError"_s);
        String message = String::format("can't modify frozen {}: {}", klass()->inspect_str(), inspect_str(env));
        auto kwargs = new HashObject(env, { "receiver"_s, receiver });
        auto args = Args({ new StringObject { message }, kwargs }, true);
        ExceptionObject *error = FrozenError.send(env, "new"_s, std::move(args))->as_exception();
        env->raise_exception(error);
    }
}

bool Object::equal(Value self, Value other) {
    if (self.is_integer() && other.is_integer())
        return self.integer() == other.integer();
    else if (self.is_integer() || other.is_integer())
        return false;

    // We still need the pointer compare for the identical NaN equality
    if (self.is_float() && other.is_float())
        return self == other.object() || self->as_float()->to_double() == other->as_float()->to_double();

    return other == self;
}

bool Object::neq(Env *env, Value self, Value other) {
    return self.send(env, "=="_s, { other }).is_falsey();
}

String Object::dbg_inspect() const {
    auto klass = m_klass->name();
    return String::format(
        "#<{}:{}>",
        klass ? *klass : "Object",
        String::hex(reinterpret_cast<nat_int_t>(this), String::HexFormat::LowercaseAndPrefixed));
}

Value Object::enum_for(Env *env, const char *method, Args &&args) {
    Vector<Value> args2(args.size() + 1);
    args2.push(SymbolObject::intern(method));
    for (size_t i = 0; i < args.size(); i++) {
        args2.push(args[i]);
    }
    return this->public_send(env, "enum_for"_s, Args(std::move(args2), args.has_keyword_hash()));
}

void Object::visit_children(Visitor &visitor) const {
    visitor.visit(m_klass);
    visitor.visit(m_singleton_class);
    if (m_ivars) {
        for (auto pair : *m_ivars) {
            visitor.visit(pair.first);
            visitor.visit(pair.second);
        }
    }
}

void Object::gc_inspect(char *buf, size_t len) const {
    snprintf(buf, len, "<Object %p type=%d class=%p>", this, (int)m_type, m_klass);
}

}
