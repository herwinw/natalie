#pragma once

namespace Natalie {

enum class ObjectType {
    Collected, // must be first
    Array,
    BigInt,
    Binding,
    Class,
    Complex,
    Dir,
    Encoding,
    Enumerator,
    EnumeratorArithmeticSequence,
    Env,
    Exception,
    False,
    Fiber,
    File,
    FileStat,
    Float,
    Hash,
    Integer,
    Io,
    MatchData,
    Method,
    Module,
    Nil,
    Object,
    Proc,
    Range,
    Random,
    Rational,
    Regexp,
    String,
    Symbol,
    Thread,
    ThreadBacktraceLocation,
    ThreadGroup,
    ThreadMutex,
    Time,
    True,
    UnboundMethod,
    VoidP,
};

}
