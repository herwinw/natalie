#include "natalie.hpp"
#include "natalie/integer_methods.hpp"
#include "natalie/ioutil.hpp"
#include "tm/defer.hpp"

#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <unistd.h>

namespace Natalie {

static inline bool flags_is_readable(const int flags) {
    return (flags & (O_RDONLY | O_WRONLY | O_RDWR)) != O_WRONLY;
}

static inline bool flags_is_writable(const int flags) {
    return (flags & (O_RDONLY | O_WRONLY | O_RDWR)) != O_RDONLY;
}

static inline bool is_readable(const int fd) {
    return flags_is_readable(fcntl(fd, F_GETFL));
}

static inline bool is_writable(const int fd) {
    return flags_is_writable(fcntl(fd, F_GETFL));
}

static void throw_unless_readable(Env *env, IoObject *const self) {
    // read(2) assigns EBADF to errno if not readable, we want an IOError instead
    auto read_closed = self->ivar_get(env, "@read_closed"_s);
    if (read_closed.is_truthy())
        env->raise("IOError", "not opened for reading");
    const auto old_errno = errno;
    if (!is_readable(self->fileno(env)))
        env->raise("IOError", "not opened for reading");
    // errno may have been changed by fcntl, revert to the old value
    env->raise_errno(old_errno);
}

static void throw_unless_writable(Env *env, IoObject *const self) {
    // write(2) assigns EBADF to errno if not writable, we want an IOError instead
    auto write_closed = self->ivar_get(env, "@write_closed"_s);
    if (write_closed.is_truthy())
        env->raise("IOError", "not opened for writing");
    const auto old_errno = errno;
    if (!is_writable(self->fileno(env)))
        env->raise("IOError", "not opened for writing");
    // errno may have been changed by fcntl, revert to the old value
    env->raise_errno(old_errno);
}

Value IoObject::initialize(Env *env, Args &&args, Block *block) {
    auto kwargs = args.pop_keyword_hash();
    args.ensure_argc_between(env, 1, 2);
    Value file_number = args.at(0);
    Value flags_obj = args.at(1, Value::nil());
    const ioutil::flags_struct wanted_flags { env, flags_obj, kwargs };
    nat_int_t fileno = file_number.to_int(env).to_nat_int_t();
    assert(fileno >= INT_MIN && fileno <= INT_MAX);
    const auto actual_flags = ::fcntl(fileno, F_GETFL);
    if (actual_flags < 0)
        env->raise_errno();
    if (wanted_flags.has_mode()) {
        if ((flags_is_readable(wanted_flags.flags()) && !flags_is_readable(actual_flags)) || (flags_is_writable(wanted_flags.flags()) && !flags_is_writable(actual_flags)))
            env->raise_errno(EINVAL);
    }
    set_fileno(fileno);
    set_encoding(env, wanted_flags.external_encoding(), wanted_flags.internal_encoding());
    m_autoclose = wanted_flags.autoclose();
    m_path = wanted_flags.path();
    if (block)
        env->warn("{}::new() does not take block; use {}::open() instead", m_klass->inspect_module(), m_klass->inspect_module());
    return this;
}

void IoObject::raise_if_closed(Env *env) const {
    if (m_closed) env->raise("IOError", "closed stream");
}

Value IoObject::advise(Env *env, Value advice, Optional<Value> offset, Optional<Value> len) {
    raise_if_closed(env);
    advice.assert_type(env, Object::Type::Symbol, "Symbol");
    nat_int_t offset_i = !offset ? 0 : IntegerMethods::convert_to_nat_int_t(env, offset.value());
    nat_int_t len_i = !len ? 0 : IntegerMethods::convert_to_nat_int_t(env, len.value());
    int advice_i = 0;
#ifdef __linux__
    if (advice == "normal"_s) {
        advice_i = POSIX_FADV_NORMAL;
    } else if (advice == "sequential"_s) {
        advice_i = POSIX_FADV_SEQUENTIAL;
    } else if (advice == "random"_s) {
        advice_i = POSIX_FADV_RANDOM;
    } else if (advice == "noreuse"_s) {
        advice_i = POSIX_FADV_NOREUSE;
    } else if (advice == "willneed"_s) {
        advice_i = POSIX_FADV_WILLNEED;
    } else if (advice == "dontneed"_s) {
        advice_i = POSIX_FADV_DONTNEED;
    } else {
        env->raise("NotImplementedError", "Unsupported advice: {}", advice.inspected(env));
    }
    if (::posix_fadvise(m_fileno, offset_i, len_i, advice_i) != 0)
        env->raise_errno();
#else
    if (advice != "normal"_s && advice != "sequential"_s && advice != "random"_s && advice != "noreuse"_s && advice != "willneed"_s && advice != "dontneed"_s) {
        env->raise("NotImplementedError", "Unsupported advice: {}", advice.as_symbol()->string());
    }
#endif
    return Value::nil();
}

Value IoObject::binread(Env *env, Value filename, Optional<Value> length, Optional<Value> offset) {
    ClassObject *File = GlobalEnv::the()->Object()->const_fetch("File"_s).as_class();
    if (filename.is_string() && filename.as_string()->string()[0] == '|')
        env->raise("NotImplementedError", "no support for pipe in IO.binread");
    FileObject *file = _new(env, File, { filename }, nullptr).as_file();
    if (offset && !offset.value().is_nil())
        file->set_pos(env, offset.value());
    file->set_encoding(env, Value(EncodingObject::get(Encoding::ASCII_8BIT)));
    auto data = file->read(env, length);
    file->close(env);
    return data;
}

Value IoObject::binwrite(Env *env, Args &&args) {
    auto kwargs = args.pop_keyword_hash();
    if (!kwargs)
        kwargs = HashObject::create();
    kwargs->put(env, "binmode"_s, Value::True());
    auto args_array = args.to_array();
    args_array->push(kwargs);
    return write_file(env, Args { args_array, true });
}

Value IoObject::dup(Env *env) const {
    auto dup_fd = ::dup(fileno(env));
    if (dup_fd < 0)
        env->raise_errno();
    auto dup_obj = _new(env, m_klass, { Value::integer(dup_fd) }, nullptr).as_io();
    dup_obj->set_close_on_exec(env, Value::True());
    dup_obj->autoclose(env, Value::True());
    return dup_obj;
}

Value IoObject::each_byte(Env *env, Block *block) {
    if (block == nullptr)
        return send(env, "enum_for"_s, { "each_byte"_s });

    Value byte;
    while (!(byte = getbyte(env)).is_nil())
        block->run(env, { byte }, nullptr);

    return this;
}

int IoObject::fileno() const {
    return m_fileno;
}

int IoObject::fileno(Env *env) const {
    raise_if_closed(env);
    return m_fileno;
}

Value IoObject::fcntl(Env *env, Value cmd_value, Optional<Value> arg_value) {
    raise_if_closed(env);
    const auto cmd = IntegerMethods::convert_to_int(env, cmd_value);
    int result;
    if (!arg_value || arg_value.value().is_nil()) {
        result = ::fcntl(m_fileno, cmd);
    } else if (arg_value.value().is_string()) {
        const auto arg = arg_value.value().as_string()->c_str();
        result = ::fcntl(m_fileno, cmd, arg);
    } else {
        const auto arg = IntegerMethods::convert_to_int(env, arg_value.value());
        result = ::fcntl(m_fileno, cmd, arg);
    }
    if (result < 0) env->raise_errno();
    return Value::integer(result);
}

int IoObject::fdatasync(Env *env) {
    raise_if_closed(env);
#ifdef __linux__
    if (::fdatasync(m_fileno) < 0) env->raise_errno();
#endif
    return 0;
}

int IoObject::fsync(Env *env) {
    raise_if_closed(env);
    if (::fsync(m_fileno) < 0) env->raise_errno();
    return 0;
}

Value IoObject::getbyte(Env *env) {
    raise_if_closed(env);
    auto result = read(env, Value::integer(1));
    if (result.is_string())
        result = result.as_string()->ord(env);
    return result;
}

Value IoObject::getc(Env *env) {
    raise_if_closed(env);
    auto line = gets(env);
    if (line.is_nil())
        return line;
    auto line_str = line.as_string();
    auto result = line_str->chr(env);
    line_str->delete_prefix_in_place(env, result);
    m_read_buffer.prepend(line_str->string());
    return result;
}

Value IoObject::inspect() const {
    TM::String details;
    if (m_path) {
        details = m_path->string();
        if (m_closed)
            details.append(" (closed)");
    } else if (m_closed) {
        details = "(closed)";
    } else {
        details = TM::String::format("fd {}", m_fileno);
    }
    return StringObject::format("#<{}:{}>", klass()->inspect_module(), details);
}

bool IoObject::is_autoclose(Env *env) const {
    raise_if_closed(env);
    return m_autoclose;
}

bool IoObject::is_binmode(Env *env) const {
    raise_if_closed(env);
    return m_external_encoding == EncodingObject::get(Encoding::ASCII_8BIT);
}

bool IoObject::is_close_on_exec(Env *env) const {
    raise_if_closed(env);
    int flags = ::fcntl(m_fileno, F_GETFD);
    if (flags < 0)
        env->raise_errno();
    return flags & FD_CLOEXEC;
}

bool IoObject::is_eof(Env *env) {
    raise_if_closed(env);
    if (!is_readable(m_fileno))
        env->raise("IOError", "not opened for reading");
    if (!m_read_buffer.is_empty())
        return false;
    size_t buffer = 0;
    if (::ioctl(m_fileno, FIONREAD, &buffer) < 0)
        env->raise_errno();
    return buffer == 0;
}

bool IoObject::is_nonblock(Env *env) const {
    const auto flags = ::fcntl(m_fileno, F_GETFL);
    if (flags < 0)
        env->raise_errno();
    return (flags & O_NONBLOCK);
}

bool IoObject::isatty(Env *env) const {
    raise_if_closed(env);
    return ::isatty(m_fileno) == 1;
}

int IoObject::lineno(Env *env) const {
    raise_if_closed(env);
    if (!is_readable(m_fileno))
        env->raise("IOError", "not opened for reading");
    return m_lineno;
}

Value IoObject::read_file(Env *env, Args &&args) {
    auto kwargs = args.pop_keyword_hash();
    args.ensure_argc_between(env, 1, 3);
    auto filename = args.at(0);
    auto length = args.at(1, Value::nil());
    auto offset = args.at(2, Value::nil());
    const ioutil::flags_struct flags { env, Value::nil(), kwargs };
    if (!flags_is_readable(flags.flags()))
        env->raise("IOError", "not opened for reading");
    if (filename.is_string() && filename.as_string()->string()[0] == '|')
        env->raise("NotImplementedError", "no support for pipe in IO.read");
    ClassObject *File = GlobalEnv::the()->Object()->const_fetch("File"_s).as_class();
    FileObject *file = _new(env, File, { filename }, nullptr).as_file();
    file->set_encoding(env, flags.external_encoding(), flags.internal_encoding());
    if (!offset.is_nil()) {
        if (offset.is_integer() && offset.integer().is_negative())
            env->raise("ArgumentError", "negative offset {} given", offset.inspected(env));
        file->set_pos(env, offset);
    }
    auto data = file->read(env, length);
    file->close(env);
    return data;
}

Value IoObject::write_file(Env *env, Args &&args) {
    auto kwargs = args.pop_keyword_hash();
    args.ensure_argc_between(env, 2, 3);

    auto filename = args.at(0);
    auto string = args.at(1);
    auto offset = args.at(2, Value::nil());
    auto mode = Value::integer(O_WRONLY | O_CREAT | O_CLOEXEC);
    Value perm = Value::nil();

    if (offset.is_nil())
        mode = Value::integer(IntegerMethods::convert_to_nat_int_t(env, mode) | O_TRUNC);
    if (kwargs && kwargs->has_key(env, "mode"_s))
        mode = kwargs->delete_key(env, "mode"_s, nullptr);
    if (kwargs && kwargs->has_key(env, "perm"_s))
        perm = kwargs->delete_key(env, "perm"_s, nullptr);
    if (filename.is_string() && filename.as_string()->string()[0] == '|')
        env->raise("NotImplementedError", "no support for pipe in IO.write");

    ClassObject *File = GlobalEnv::the()->Object()->const_fetch("File"_s).as_class();
    FileObject *file = nullptr;

    if (kwargs && kwargs->has_key(env, "open_args"_s)) {
        auto next_args = ArrayObject::create({ filename });
        next_args->concat(*kwargs->fetch(env, "open_args"_s).to_ary(env));
        auto open_args_has_kw = next_args->last().is_hash();
        file = _new(env, File, Args(next_args, open_args_has_kw), nullptr).as_file();
    } else {
        auto next_args = ArrayObject::create({ filename, mode });
        if (!perm.is_nil())
            next_args->push(perm);
        if (kwargs)
            next_args->push(kwargs);
        file = _new(env, File, Args(next_args, kwargs != nullptr), nullptr).as_file();
    }
    if (!offset.is_nil())
        file->set_pos(env, offset);
    Defer close { [&file, &env]() { file->close(env); } };
    int bytes_written = file->write(env, string);
    return Value::integer(bytes_written);
}

#define NAT_READ_BYTES 1024

ssize_t IoObject::blocking_read(Env *env, void *buf, int count) const {
    Defer done_sleeping([] { ThreadObject::set_current_sleeping(false); });
    ThreadObject::set_current_sleeping(true);

    select_read(env);
    return ::read(m_fileno, buf, count);
}

Value IoObject::read(Env *env, Optional<Value> count_arg, Optional<Value> buffer_arg) {
    raise_if_closed(env);
    auto buffer = Value::nil();
    if (buffer_arg && !buffer_arg.value().is_nil())
        buffer = buffer_arg.value().to_str(env);
    ssize_t bytes_read;
    if (count_arg && !count_arg.value().is_nil()) {
        const auto count = IntegerMethods::convert_to_native_type<size_t>(env, count_arg.value());
        if (m_read_buffer.size() >= count) {
            auto result = StringObject::create(m_read_buffer.c_str(), static_cast<size_t>(count), Encoding::ASCII_8BIT);
            m_read_buffer = String { m_read_buffer.c_str() + count, m_read_buffer.size() - count };
            return result;
        }
        TM::String buf(count - m_read_buffer.size(), '\0');
        bytes_read = blocking_read(env, &buf[0], count - m_read_buffer.size());
        if (bytes_read < 0)
            throw_unless_readable(env, this);
        buf.truncate(bytes_read);
        buf.prepend(m_read_buffer);
        m_read_buffer.clear();
        if (buf.is_empty()) {
            if (!buffer.is_nil())
                buffer.as_string()->clear(env);
            if (count == 0) {
                if (!buffer.is_nil())
                    return buffer;
                return StringObject::create("", 0, Encoding::ASCII_8BIT);
            }
            return Value::nil();
        } else if (!buffer.is_nil()) {
            buffer.as_string()->set_str(buf.c_str(), static_cast<size_t>(bytes_read));
            return buffer;
        } else {
            return StringObject::create(std::move(buf), Encoding::ASCII_8BIT);
        }
    }
    char buf[NAT_READ_BYTES + 1];
    bytes_read = blocking_read(env, buf, NAT_READ_BYTES);
    StringObject *str = nullptr;
    if (!buffer.is_nil()) {
        str = buffer.as_string();
    } else if (m_external_encoding != nullptr) {
        str = StringObject::create("", m_external_encoding);
    } else {
        str = StringObject::create();
    }
    if (bytes_read < 0) {
        throw_unless_readable(env, this);
    } else if (bytes_read == 0) {
        str->clear(env);
        str->prepend(env, { StringObject::create(std::move(m_read_buffer)) });
        m_read_buffer.clear();
        return str;
    } else {
        str->set_str(buf, bytes_read);
    }
    while (1) {
        bytes_read = blocking_read(env, buf, NAT_READ_BYTES);
        if (bytes_read < 0) env->raise_errno();
        if (bytes_read == 0) break;
        buf[bytes_read] = 0;
        str->append(buf, bytes_read);
    }
    str->prepend(env, { StringObject::create(std::move(m_read_buffer)) });
    m_read_buffer.clear();
    return str;
}

Value IoObject::ltlt(Env *env, Value obj) {
    write(env, obj);
    return this;
}

Value IoObject::autoclose(Env *env, Value value) {
    raise_if_closed(env);
    m_autoclose = value.is_truthy();
    return value;
}

Value IoObject::binmode(Env *env) {
    raise_if_closed(env);
    m_external_encoding = EncodingObject::get(Encoding::ASCII_8BIT);
    m_internal_encoding = nullptr;
    return this;
}

Value IoObject::copy_stream(Env *env, Value src, Value dst, Optional<Value> src_length, Optional<Value> src_offset) {
    Value data = StringObject::create();
    if (src.is_io() || src.respond_to(env, "to_io"_s)) {
        auto src_io = src.to_io(env);
        if (!is_readable(src_io->fileno(env)))
            env->raise("IOError", "not opened for reading");
        if (src_offset && !src_offset.value().is_nil()) {
            // FIXME: src_length can be missing
            src_io->pread(env, src_length.value(), src_offset.value(), data);
        } else {
            src_io->read(env, src_length, data);
        }
    } else if (src.respond_to(env, "read"_s)) {
        src.send(env, "read"_s, { src_length.value_or(Value::nil()), data });
    } else if (src.respond_to(env, "readpartial"_s)) {
        src.send(env, "readpartial"_s, { src_length.value_or(Value::nil()), data });
    } else {
        data = read_file(env, { src, src_length.value_or(Value::nil()), src_offset.value_or(Value::nil()) });
    }

    if (dst.is_io() || dst.respond_to(env, "to_io"_s)) {
        auto dst_io = dst.to_io(env);
        return Value::integer(dst_io->write(env, data));
    } else if (dst.respond_to(env, "write"_s)) {
        return dst.send(env, "write"_s, { data });
    } else {
        return write_file(env, { dst, data });
    }
}

int IoObject::write(Env *env, Value obj) {
    raise_if_closed(env);

    auto str = obj.to_s(env);
    if (str->is_empty())
        return 0;

    size_t total_written = 0;
    const char *buf = str->c_str();
    auto size = str->bytesize();

    while (total_written < size) {
        ssize_t written = ::write(m_fileno, buf + total_written, size - total_written);
        if (written == -1) {
            switch (errno) {
            case EINTR:
            case EAGAIN:
                continue;
            default:
                throw_unless_writable(env, this);
            }
        }
        total_written += written;
    }

    if (m_sync) ::fsync(m_fileno);

    return total_written;
}

Value IoObject::write(Env *env, Args &&args) {
    int bytes_written = 0;
    for (size_t i = 0; i < args.size(); i++) {
        bytes_written += write(env, args[i]);
    }
    return Value::integer(bytes_written);
}

Value IoObject::write_nonblock(Env *env, Value obj, Optional<Value> exception_kwarg) {
    raise_if_closed(env);
    obj = obj.to_s(env);
    set_nonblock(env, true);
    obj.assert_type(env, Object::Type::String, "String");
    const auto result = ::write(m_fileno, obj.as_string()->c_str(), obj.as_string()->bytesize());
    if (result == -1) {
        if (errno == EWOULDBLOCK || errno == EAGAIN) {
            if (exception_kwarg && exception_kwarg.value().is_false())
                return "wait_writable"_s;
            auto SystemCallError = find_top_level_const(env, "SystemCallError"_s);
            ExceptionObject *error = SystemCallError.send(env, "exception"_s, { Value::integer(errno) }).as_exception();
            auto WaitWritable = klass()->const_fetch("WaitWritable"_s).as_module();
            error->extend_once(env, WaitWritable);
            env->raise_exception(error);
        }
        throw_unless_writable(env, this);
    }
    return Value::integer(result);
}

Value IoObject::gets(Env *env, Optional<Value> sep_arg, Optional<Value> limit_arg, Optional<Value> chomp) {
    raise_if_closed(env);
    auto line = StringObject::create();
    Value sep = Value::nil();
    if (sep_arg && !sep_arg.value().is_nil()) {
        sep = sep_arg.value();
        if (sep.is_integer() || sep.respond_to(env, "to_int"_s)) {
            limit_arg = sep;
            sep_arg = Optional<Value>();
        } else {
            sep = sep.to_str(env);
            if (sep.as_string()->is_empty())
                sep = StringObject::create("\n\n");
        }
    }

    if (!sep_arg)
        sep = env->global_get("$/"_s);

    bool has_limit = false;
    auto limit = Value::integer(NAT_READ_BYTES);
    if (limit_arg) {
        limit = limit_arg.value().to_int(env);
        has_limit = true;
    }

    if (sep.is_nil())
        return read(env, has_limit ? limit : Optional<Value>());

    auto sep_string = sep.as_string_or_raise(env)->string();

    while (true) {
        Value chunk;

        if (m_read_buffer.find(sep_string) != -1) {
            chunk = StringObject::create(m_read_buffer);
        } else {
            chunk = read(env, limit);
            if (chunk.is_nil()) {
                if (line->is_empty()) {
                    env->set_last_line(Value::nil());
                    return Value::nil();
                }
                break;
            }
        }

        line->append(chunk);
        if (has_limit || line->include(env, sep))
            break;
    }

    auto split = line->split(env, sep, Value::integer(2)).as_array();
    if (split->size() == 2) {
        line = split->at(0).as_string();
        if (!chomp || chomp.value().is_falsey())
            line->append(sep);
        m_read_buffer = split->at(1).as_string()->string();
    }

    m_lineno++;
    env->set_last_line(line);
    env->set_last_lineno(Value::integer(m_lineno));
    return line;
}

Value IoObject::get_path() const {
    if (m_path == nullptr)
        return Value::nil();
    return StringObject::create(*m_path);
}

Value IoObject::pid(Env *env) const {
    if (m_pid == -1)
        return Value::nil();
    raise_if_closed(env);
    return Value::integer(m_pid);
}

Value IoObject::pread(Env *env, Value count, Value offset, Optional<Value> out_arg) {
    raise_if_closed(env);
    if (!is_readable(m_fileno))
        env->raise("IOError", "not opened for reading");
    const auto count_int = count.to_int(env).to_nat_int_t();
    if (count_int < 0)
        env->raise("ArgumentError", "negative string size (or size too big)");
    const auto offset_int = offset.to_int(env).to_nat_int_t();
    TM::String buf(count_int, '\0');
    const auto bytes_read = ::pread(m_fileno, &buf[0], count_int, offset_int);
    if (bytes_read < 0)
        env->raise_errno();
    if (bytes_read == 0) {
        if (count_int == 0)
            return StringObject::create(std::move(buf));
        env->raise("EOFError", "end of file reached");
    }
    buf.truncate(bytes_read);
    if (out_arg && !out_arg.value().is_nil()) {
        auto out_string = out_arg.value().to_str(env);
        out_string->set_str(buf.c_str(), buf.size());
        return out_string;
    }
    return StringObject::create(std::move(buf));
}

Value IoObject::putc(Env *env, Value val) {
    raise_if_closed(env);
    Integer ord;
    if (val.is_string()) {
        ord = val.as_string()->ord(env).integer();
    } else {
        ord = IntegerMethods::convert_to_nat_int_t(env, val) & 0xff;
    }
    send(env, "write"_s, { IntegerMethods::chr(env, ord) });
    return val;
}

void IoObject::putstr(Env *env, StringObject *str) {
    String sstr = str->string();
    send(env, "write"_s, Args({ str }));
    if (sstr.size() == 0 || (sstr.size() > 0 && !sstr.ends_with("\n"))) {
        send(env, "write"_s, Args({ StringObject::create("\n") }));
    }
}

void IoObject::putary(Env *env, ArrayObject *ary) {
    for (auto &item : *ary) {
        this->puts(env, item);
    }
}

void IoObject::puts(Env *env, Value val) {
    if (val.is_string()) {
        this->putstr(env, val.as_string());
    } else if (val.is_array() || val.respond_to(env, "to_ary"_s)) {
        this->putary(env, val.to_ary(env));
    } else {
        Value str = val.send(env, "to_s"_s);
        if (str.is_string()) {
            this->putstr(env, str.as_string());
        } else { // to_s did not return a string, so inspect val instead.
            this->putstr(env, StringObject::create(val.inspected(env)));
        }
    }
}

Value IoObject::puts(Env *env, Args &&args) {
    if (args.size() == 0) {
        send(env, "write"_s, Args({ StringObject::create("\n") }));
    } else {
        for (size_t i = 0; i < args.size(); i++) {
            this->puts(env, args[i]);
        }
    }
    return Value::nil();
}

Value IoObject::print(Env *env, Args &&args) {
    if (args.size() > 0) {
        auto fsep = env->output_file_separator();
        auto valid_fsep = !fsep.is_nil();
        for (size_t i = 0; i < args.size(); i++) {
            if (i > 0 && valid_fsep)
                write(env, fsep);
            write(env, args[i]);
        }
    } else {
        Value lastline = env->last_line();
        write(env, lastline);
    }
    auto rsep = env->output_record_separator();
    if (!rsep.is_nil()) write(env, rsep);
    return Value::nil();
}

Value IoObject::pwrite(Env *env, Value data, Value offset) {
    raise_if_closed(env);
    if (!is_writable(m_fileno))
        env->raise("IOError", "not opened for writing");
    auto offset_int = IntegerMethods::convert_to_nat_int_t(env, offset);
    auto str = data.to_s(env);
    auto result = ::pwrite(m_fileno, str->c_str(), str->bytesize(), offset_int);
    if (result < 0)
        env->raise_errno();
    return Value::integer(result);
}

Value IoObject::close(Env *env) {
    if (m_closed || !m_autoclose)
        return Value::nil();

    m_closed = true;

    if (m_fileno == STDIN_FILENO || m_fileno == STDOUT_FILENO || m_fileno == STDERR_FILENO)
        return Value::nil();

    // Wake up all threads in case one is blocking on a read to this fd.
    // It is undefined behavior on Linux to continue a read() or select()
    // on a closed file descriptor.
    ThreadObject::wake_all();

    int result;
    if (m_fileptr && m_pid > 0) {
        result = pclose2(m_fileptr, m_pid);
        set_status_object(env, m_pid, result);
    } else {
        result = ::close(m_fileno);
    }
    if (result == -1)
        env->raise_errno();

    m_fileno = -1;

    return Value::nil();
}

Value IoObject::seek(Env *env, Value amount_value, Optional<Value> whence_arg) {
    raise_if_closed(env);
    nat_int_t amount = IntegerMethods::convert_to_nat_int_t(env, amount_value);
    int whence = 0;
    if (whence_arg) {
        auto whence_value = whence_arg.value();
        if (whence_value.is_integer()) {
            whence = whence_value.integer().to_nat_int_t();
        } else if (whence_value.is_symbol()) {
            SymbolObject *whence_sym = whence_value.as_symbol();
            if (whence_sym->string() == "SET") {
                whence = SEEK_SET;
            } else if (whence_sym->string() == "CUR") {
                whence = SEEK_CUR;
            } else if (whence_sym->string() == "END") {
                whence = SEEK_END;
            } else {
                env->raise("TypeError", "no implicit conversion of Symbol into Integer");
            }
        } else {
            env->raise("TypeError", "no implicit conversion of {} into Integer", whence_value.klass()->inspect_module());
        }
    }
    if (whence == SEEK_CUR && !m_read_buffer.is_empty())
        amount -= m_read_buffer.size();
    int result = lseek(m_fileno, amount, whence);
    if (result == -1)
        env->raise_errno();
    m_read_buffer.clear();
    return Value::integer(0);
}

Value IoObject::set_close_on_exec(Env *env, Value value) {
    raise_if_closed(env);
    int flags = ::fcntl(m_fileno, F_GETFD);
    if (flags < 0)
        env->raise_errno();
    if (value.is_truthy()) {
        flags |= FD_CLOEXEC;
    } else {
        flags &= ~FD_CLOEXEC;
    }
    if (::fcntl(m_fileno, F_SETFD, flags) < 0)
        env->raise_errno();
    return value;
}
Value IoObject::set_encoding(Env *env, Optional<EncodingObject *> ext_arg, Optional<EncodingObject *> int_arg) {
    auto e = ext_arg && ext_arg.value() ? Value(ext_arg.value()) : Value::nil();
    auto i = int_arg && int_arg.value() ? Value(int_arg.value()) : Value::nil();
    return set_encoding(env, e, i);
}

Value IoObject::set_encoding(Env *env, Optional<Value> ext_arg, Optional<Value> int_arg) {
    Value ext_enc = ext_arg.value_or(Value::nil());
    Value int_enc = int_arg.value_or(Value::nil());

    if (int_enc.is_nil() && ext_arg && (ext_enc.is_string() || ext_enc.respond_to(env, "to_str"_s))) {
        ext_enc = ext_enc.to_str(env);
        if (ext_enc.as_string()->include(":")) {
            Value colon = StringObject::create(":");
            auto encsplit = ext_enc.to_str(env)->split(env, colon).as_array();
            ext_enc = encsplit->ref(env, Value::integer(static_cast<nat_int_t>(0)));
            int_enc = encsplit->ref(env, Value::integer(static_cast<nat_int_t>(1)));
        }
    }

    if (ext_enc != nullptr && !ext_enc.is_nil()) {
        if (ext_enc.is_encoding()) {
            m_external_encoding = ext_enc.as_encoding();
        } else {
            m_external_encoding = EncodingObject::find_encoding(env, ext_enc.to_str(env));
        }
    }
    if (int_enc != nullptr && !int_enc.is_nil()) {
        if (int_enc.is_encoding()) {
            m_internal_encoding = int_enc.as_encoding();
        } else {
            m_internal_encoding = EncodingObject::find_encoding(env, int_enc.to_str(env));
        }
    }

    return this;
}

Value IoObject::set_lineno(Env *env, Value lineno) {
    raise_if_closed(env);
    if (!is_readable(m_fileno))
        env->raise("IOError", "not opened for reading");
    m_lineno = IntegerMethods::convert_to_int(env, lineno);
    return lineno;
}

Value IoObject::set_sync(Env *env, Value value) {
    raise_if_closed(env);
    m_sync = value.is_truthy();
    return value;
}

void IoObject::set_nonblock(Env *env, bool enable) const {
    auto flags = ::fcntl(fileno(), F_GETFL);
    if (flags < 0)
        env->raise_errno();
    if (enable) {
        if (!(flags & O_NONBLOCK)) {
            flags |= O_NONBLOCK;
            if (::fcntl(fileno(), F_SETFL, flags) < 0)
                env->raise_errno();
        }
    } else {
        if (flags & O_NONBLOCK) {
            flags &= ~O_NONBLOCK;
            if (::fcntl(fileno(), F_SETFL, flags) < 0)
                env->raise_errno();
        }
    }
}

Value IoObject::stat(Env *env) const {
    struct stat sb;
    auto file_desc = fileno(env); // current file descriptor
    int result = ::fstat(file_desc, &sb);
    if (result < 0) env->raise_errno();
    return FileStatObject::create(sb);
}

Value IoObject::sysopen(Env *env, Value path, Optional<Value> flags_obj, Optional<Value> perm) {
    const ioutil::flags_struct flags { env, flags_obj.value_or(Value::nil()), nullptr };
    const auto modenum = ioutil::perm_to_mode(env, perm.value_or(Value::nil()));

    path = ioutil::convert_using_to_path(env, path);
    const auto fd = ::open(path.as_string()->c_str(), flags.flags(), modenum);
    return Value::integer(fd);
}

IoObject *IoObject::to_io(Env *env) {
    return this;
}

Value IoObject::try_convert(Env *env, Value val) {
    if (val.is_io()) {
        return val;
    } else if (val.respond_to(env, "to_io"_s)) {
        auto io = val.send(env, "to_io"_s);
        if (!io.is_io())
            env->raise(
                "TypeError", "can't convert {} to IO ({}#to_io gives {})",
                val.klass()->inspect_module(),
                val.klass()->inspect_module(),
                io.klass()->inspect_module());
        return io;
    }
    return Value::nil();
}

Value IoObject::ungetbyte(Env *env, Value byte) {
    raise_if_closed(env);
    if (!is_readable(m_fileno))
        env->raise("IOError", "not opened for reading");
    if (byte.is_nil())
        return Value::nil();
    if (byte.is_integer()) {
        nat_int_t value = 0xff;
        if (!byte.integer().is_bignum()) {
            value = IntegerMethods::convert_to_nat_int_t(env, byte);
            if (value > 0xff) value = 0xff;
        }
        m_read_buffer.prepend_char(static_cast<char>(value & 0xff));
    } else {
        const auto &value = byte.to_str(env)->string();
        m_read_buffer.prepend(value);
    }
    return Value::nil();
}

Value IoObject::ungetc(Env *env, Value c) {
    if (c.is_integer())
        return ungetbyte(env, c);
    return ungetbyte(env, c.to_str(env));
}

Value IoObject::wait(Env *env, Args &&args) {
    raise_if_closed(env);

    nat_int_t events = 0;
    Value timeout = Value::nil();
    bool return_self = false;

    if (args.size() == 2 && args.at(0, Value::nil()).is_integer() && args.at(1, Value::nil()).is_numeric()) {
        events = args[0].to_int(env).to_nat_int_t();
        timeout = args[1];

        if (events <= 0)
            env->raise("ArgumentError", "Events must be positive integer!");
    } else {
        return_self = true;
        for (size_t i = 0; i < args.size(); i++) {
            if (args[i].is_nil()) {
                continue;
            } else if (args[i].is_numeric()) {
                if (!timeout.is_nil())
                    env->raise("ArgumentError", "timeout given more than once");
                timeout = args[i];
            } else if (args[i].is_symbol()) {
                const auto &str = args[i].as_symbol()->string();
                if (str == "r" || str == "read" || str == "readable") {
                    events |= WAIT_READABLE;
                } else if (str == "w" || str == "write" || str == "writable") {
                    events |= WAIT_WRITABLE;
                } else if (str == "rw" || str == "read_write" || str == "readable_writable") {
                    events |= (WAIT_READABLE | WAIT_WRITABLE);
                } else {
                    env->raise("ArgumentError", "unsupported mode: {}", str);
                }
            } else {
                env->raise("ArgumentError", "invalid input in IO#wait");
            }
        }
        if (events == 0)
            events = WAIT_READABLE;
    }

    auto read_ios = ArrayObject::create();
    if (events & WAIT_READABLE)
        read_ios->push(this);
    auto write_ios = ArrayObject::create();
    if (events & WAIT_WRITABLE)
        write_ios->push(this);
    auto select_result = IoObject::select(env, Value(read_ios), Value(write_ios), {}, timeout);
    nat_int_t result = 0;
    if (select_result.is_array()) {
        auto select_array = select_result.as_array();
        if (!select_array->at(0).as_array()->is_empty())
            result |= WAIT_READABLE;
        if (!select_array->at(1).as_array()->is_empty())
            result |= WAIT_WRITABLE;
    }

    if (result == 0)
        return Value::nil();
    if (return_self)
        return this;
    return Value::integer(result);
}

Value IoObject::wait_readable(Env *env, Optional<Value> timeout) {
    return wait(env, { "read"_s, timeout.value_or(Value::nil()) });
}

Value IoObject::wait_writable(Env *env, Optional<Value> timeout) {
    return wait(env, { "write"_s, timeout.value_or(Value::nil()) });
}

int IoObject::rewind(Env *env) {
    raise_if_closed(env);
    errno = 0;
    auto result = ::lseek(m_fileno, 0, SEEK_SET);
    if (result < 0 && errno) env->raise_errno();
    m_lineno = 0;
    m_read_buffer.clear();
    return 0;
}

int IoObject::set_pos(Env *env, Value position) {
    raise_if_closed(env);
    nat_int_t offset = IntegerMethods::convert_to_nat_int_t(env, position);
    errno = 0;
    auto result = ::lseek(m_fileno, offset, SEEK_SET);
    if (result < 0 && errno) env->raise_errno();
    m_read_buffer.clear();
    return result;
}

bool IoObject::sync(Env *env) const {
    raise_if_closed(env);
    return m_sync;
}

Value IoObject::sysread(Env *env, Value amount, Optional<Value> buffer) {
    if (amount.to_int(env).is_zero() && buffer && !buffer.value().is_nil())
        return buffer.value();
    if (!m_read_buffer.is_empty())
        env->raise("IOError", "sysread for buffered IO");
    auto result = read(env, amount, buffer);
    if (result.is_nil()) {
        if (buffer && !buffer.value().is_nil())
            buffer.value().to_str(env)->clear(env);
        env->raise("EOFError", "end of file reached");
    }
    return result;
}

Value IoObject::sysseek(Env *env, Value amount, Optional<Value> whence) {
    if (!m_read_buffer.is_empty())
        env->raise("IOError", "sysseek for buffered IO");
    seek(env, amount, whence);
    return Value::integer(pos(env));
}

Value IoObject::syswrite(Env *env, Value obj) {
    raise_if_closed(env);

    auto str = obj.to_s(env);
    if (str->is_empty())
        return Value::integer(0);

    auto result = ::write(m_fileno, str->c_str(), str->bytesize());
    if (result == -1)
        throw_unless_writable(env, this);

    if (m_sync) ::fsync(m_fileno);

    return Value::integer(result);
}

static bool any_closed(ArrayObject *ios) {
    for (auto io : *ios) {
        if (io.is_io() && io.as_io()->is_closed())
            return true;
    }
    return false;
}

static fd_set create_fd_set(Env *env, ArrayObject *ios, int *nfds) {
    fd_set result;
    FD_ZERO(&result);

    if (!ios)
        return result;

    for (auto io : *ios) {
        const auto fd = io.to_io(env)->fileno();
        FD_SET(fd, &result);
        *nfds = std::max(*nfds, fd + 1);
    }
    return result;
};

static ArrayObject *create_output_fds(Env *env, fd_set *fds, ArrayObject *ios) {
    auto result = ArrayObject::create();

    if (!ios)
        return result;

    for (auto io : *ios) {
        const auto fd = io.to_io(env)->fileno();
        if (FD_ISSET(fd, fds))
            result->push(io);
    }
    return result;
};

Value IoObject::select(Env *env, Value read_ios, Optional<Value> write_ios, Optional<Value> error_ios, Optional<Value> timeout) {
    timeval timeout_tv = { 0, 0 }, *timeout_ptr = nullptr;

    if (timeout && !timeout.value().is_nil()) {
        const auto timeout_f = timeout.value().to_f(env)->to_double();
        if (timeout_f < 0)
            env->raise("ArgumentError", "time interval must not be negative");
        timeout_tv.tv_sec = static_cast<int>(timeout_f);
        timeout_tv.tv_usec = (timeout_f - timeout_tv.tv_sec) * 1000000;
        timeout_ptr = &timeout_tv;
    }

    auto read_ios_ary = !read_ios.is_nil() ? read_ios.to_ary(env) : ArrayObject::create();
    auto write_ios_ary = write_ios && !write_ios.value().is_nil() ? write_ios.value().to_ary(env) : ArrayObject::create();
    auto error_ios_ary = error_ios && !error_ios.value().is_nil() ? error_ios.value().to_ary(env) : ArrayObject::create();

    auto wake_pipe_fileno = ThreadObject::wake_pipe_read_fileno();

    int nfds = 0;
    auto read_fds = create_fd_set(env, read_ios_ary, &nfds);
    auto write_fds = create_fd_set(env, write_ios_ary, &nfds);
    auto error_fds = create_fd_set(env, error_ios_ary, &nfds);

    FD_SET(wake_pipe_fileno, &read_fds);
    nfds = std::max(nfds, wake_pipe_fileno + 1);

    fd_set read_fds_copy = read_fds;
    fd_set write_fds_copy = write_fds;
    fd_set error_fds_copy = error_fds;

    Defer done_sleeping([] { ThreadObject::set_current_sleeping(false); });
    ThreadObject::set_current_sleeping(true);

    int result;
    for (;;) {
        result = ::select(nfds, &read_fds, &write_fds, &error_fds, timeout_ptr);
        if (result == -1 && errno == EINTR) {
            // Interrupted by a signal -- probably the GC stopping the world.
            // Try again.
        } else if (result == -1) {
            // An error the user needs to handle.
            break;
        } else if (FD_ISSET(wake_pipe_fileno, &read_fds)) {
            // Interrupted by our thread file descriptor.
            // This thread may need to raise or exit.
            ThreadObject::clear_wake_pipe();
            ThreadObject::check_current_exception(env);
            if (any_closed(read_ios_ary) || any_closed(write_ios_ary) || any_closed(error_ios_ary))
                env->raise("IOError", "closed stream");
        } else {
            // Only thing left is one of the file descriptors
            // we were waiting on got an update.
            break;
        }

        read_fds = read_fds_copy;
        write_fds = write_fds_copy;
        error_fds = error_fds_copy;
    }

    if (result == -1)
        env->raise_errno();

    if (result == 0)
        return Value::nil();

    FD_CLR(wake_pipe_fileno, &read_fds);

    auto readable_ios = create_output_fds(env, &read_fds, read_ios_ary);
    auto writeable_ios = create_output_fds(env, &write_fds, write_ios_ary);
    auto errorable_ios = create_output_fds(env, &error_fds, error_ios_ary);
    return ArrayObject::create({ readable_ios, writeable_ios, errorable_ios });
}

void IoObject::select_read(Env *env, timeval *timeout) const {
    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(m_fileno, &readfds);
    auto wake_pipe_fileno = ThreadObject::wake_pipe_read_fileno();
    FD_SET(wake_pipe_fileno, &readfds);
    auto nfds = std::max(m_fileno, wake_pipe_fileno) + 1;

    fd_set readfds_copy = readfds;

    if (m_closed)
        env->raise("IOError", "closed stream");

    int ret;
    for (;;) {
        ret = ::select(nfds, &readfds, nullptr, nullptr, timeout);

        if (ret == -1) {
            if (errno == EINTR) {
                // Interrupted by a signal -- probably the GC stopping the world.
                // Try again.
                readfds = readfds_copy;
                continue;
            } else if (errno == EBADF && m_closed) {
                // On macOS, the blocking select() call returns an error
                // when the file is closed. This can also happen on Linux
                // if the file was closed just prior to our select() call.
                env->raise("IOError", "closed stream");
            } else {
                env->raise_errno();
            }
        }

        if (FD_ISSET(wake_pipe_fileno, &readfds)) {
            ThreadObject::clear_wake_pipe();
            ThreadObject::check_current_exception(env);
            if (m_closed)
                env->raise("IOError", "closed stream");
        }

        if (FD_ISSET(m_fileno, &readfds))
            break;

        readfds = readfds_copy;
    }

    assert(ret != -1);
}

Value IoObject::pipe(Env *env, ClassObject *klass, Optional<Value> external_encoding, Optional<Value> internal_encoding, Block *block) {
    int pipefd[2];
    if (pipe2(pipefd, O_CLOEXEC | O_NONBLOCK) < 0)
        env->raise_errno();

    auto io_read = _new(env, klass, { Value::integer(pipefd[0]) }, nullptr);
    auto io_write = _new(env, klass, { Value::integer(pipefd[1]) }, nullptr);
    io_read.as_io()->set_encoding(env, external_encoding, internal_encoding);
    auto pipes = ArrayObject::create({ io_read, io_write });

    if (!block)
        return pipes;

    Defer close_pipes([&]() {
        io_read->public_send(env, "close"_s);
        io_write->public_send(env, "close"_s);
    });
    return block->run(env, { pipes }, nullptr);
}

Value IoObject::popen(Env *env, ClassObject *klass, Args &&args, Block *block) {
    if (args.has_keyword_hash())
        env->raise("NotImplementedError", "IO.popen with keyword arguments is not yet supported");
    if (args.size() > 2)
        env->raise("NotImplementedError", "IO.popen with env is not yet supported");
    args.ensure_argc_between(env, 1, 3);
    auto command = args.at(0).to_str(env);
    if (*command->c_str() == '-')
        env->raise("NotImplementedError", "IO.popen with \"-\" to fork is not yet supported");
    auto type = args.at(1, StringObject::create("r")).to_str(env);
    pid_t pid;
    auto fileptr = popen2(command->c_str(), type->c_str(), pid);
    if (!fileptr)
        env->raise_errno();
    auto io = _new(env, klass, { Value::integer(::fileno(fileptr)) }, nullptr);
    io.as_io()->m_fileptr = fileptr;
    io.as_io()->m_pid = pid;

    if (!block)
        return io;

    Defer close_io([&]() { io->public_send(env, "close"_s); });
    return block->run(env, { io }, nullptr);
}

int IoObject::pos(Env *env) {
    raise_if_closed(env);
    errno = 0;
    auto result = ::lseek(m_fileno, 0, SEEK_CUR);
    if (result < 0 && errno) env->raise_errno();
    return result - m_read_buffer.size();
}

// This is a variant of getbyte that raises EOFError
Value IoObject::readbyte(Env *env) {
    auto result = getbyte(env);
    if (result.is_nil())
        env->raise("EOFError", "end of file reached");
    return result;
}

// This is a variant of gets that raises EOFError
// NATFIXME: Add arguments when those features are
//  added to IOObject::gets()
Value IoObject::readline(Env *env, Optional<Value> sep, Optional<Value> limit, Optional<Value> chomp) {
    auto result = gets(env, sep, limit, chomp);
    if (result.is_nil())
        env->raise("EOFError", "end of file reached");
    return result;
}

void IoObject::build_constants(Env *, ClassObject *klass) {
    klass->const_set("SEEK_SET"_s, Value::integer(SEEK_SET));
    klass->const_set("SEEK_CUR"_s, Value::integer(SEEK_CUR));
    klass->const_set("SEEK_END"_s, Value::integer(SEEK_END));
    klass->const_set("SEEK_DATA"_s, Value::integer(SEEK_DATA));
    klass->const_set("SEEK_HOLE"_s, Value::integer(SEEK_HOLE));

    klass->const_set("READABLE"_s, Value::integer(WAIT_READABLE));
    klass->const_set("PRIORITY"_s, Value::integer(WAIT_PRIORITY));
    klass->const_set("WRITABLE"_s, Value::integer(WAIT_WRITABLE));
}

}
