#include "natalie.hpp"
#include "natalie/ioutil.hpp"

#include <errno.h>
#include <fcntl.h>
#include <filesystem>
// #include <fnmatch.h> // use ruby defined values instead of os-defined
#include <sys/file.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <utime.h>

namespace Natalie {

// wrapper to implement euidaccess() for certain systems which
// do not have it.
static int effective_uid_access(const char *path_name, int type) {
#if defined(__OpenBSD__) or defined(__APPLE__)
    uid_t real_uid = ::getuid();
    uid_t effective_uid = ::geteuid();
    gid_t real_gid = ::getgid();
    gid_t effective_gid = ::getegid();
    // if real user/group id's are the same as the effective
    // user/group id's then we can just use access(), yay!
    if (real_uid == effective_uid && real_gid == effective_gid)
        return ::access(path_name, type);
    // NATFIXME: this behavior is probably wrong, but passes specs
    // because real/effective are always equal in the tests.
    return -1;
#else
    // linux systems have an euid_access function so call it
    // directly.
    return ::euidaccess(path_name, type);
#endif
}

Value FileObject::initialize(Env *env, Args &&args, Block *block) {
    auto kwargs = args.pop_keyword_hash();
    args.ensure_argc_between(env, 1, 3);
    auto filename = args.at(0);
    auto flags_obj = args.at(1, Value::nil());
    auto perm = args.at(2, Value::nil());
    const ioutil::flags_struct flags { env, flags_obj, kwargs };
    const auto modenum = ioutil::perm_to_mode(env, perm);

    if (filename.is_integer()) { // passing in a number uses fd number
        int fileno = IntegerMethods::convert_to_int(env, filename);
        String flags_str = String('r');
        if (!flags_obj.is_nil()) {
            flags_obj.assert_type(env, Object::Type::String, "String");
            flags_str = flags_obj.as_string()->string();
        }
        FILE *fptr = ::fdopen(fileno, flags_str.c_str());
        if (fptr == nullptr) env->raise_errno();
        set_fileno(fileno);
    } else {
        filename = ioutil::convert_using_to_path(env, filename);
        int fileno = ::open(filename.as_string()->c_str(), flags.flags(), modenum);
        if (fileno == -1) env->raise_errno();
        set_fileno(fileno);
        set_path(filename.as_string());
    }
    set_encoding(env, flags.external_encoding(), flags.internal_encoding());
    if (block)
        env->warn("File::new() does not take block; use File::open() instead");
    return this;
}

Value FileObject::absolute_path(Env *env, Value path, Optional<Value> dir_arg) {
    path = ioutil::convert_using_to_path(env, path);
    if (path.as_string()->start_with(env, { StringObject::create("/") }))
        return path;
    if ((!dir_arg || dir_arg->is_nil()) && path.as_string()->eq(env, StringObject::create("~")))
        return path;

    auto File = GlobalEnv::the()->Object()->const_fetch("File"_s);
    auto dir = dir_arg && !dir_arg->is_nil() ? dir_arg.value() : DirObject::pwd(env);
    return File.send(env, "join"_s, { dir, path });
}

Value FileObject::expand_path(Env *env, Value path, Optional<Value> dir_arg) {
    auto expand_tilde = [&](String &&string) {
        if (string.is_empty() || string[0] != '~')
            return std::move(string);

        String user;
        size_t len = 0;
        for (; len + 1 < string.length(); len++) {
            if (string[1 + len] == '/')
                break;
        }
        if (len > 0)
            user = string.substring(1, len);

        String home;
        if (user.is_empty()) {
            // if HOME is set, use that...
            auto home_ptr = getenv("HOME");
            if (home_ptr) {
                home = home_ptr;
            } else {
                // if not, use the password database...
                auto pw = getpwuid(getuid());
                if (!pw)
                    home = "~";
                else
                    home = pw->pw_dir;
            }
        } else {
            auto pw = getpwnam(user.c_str());
            if (!pw)
                env->raise("ArgumentError", "user {} doesn't exist", user);
            else
                home = pw->pw_dir;
        }

        if (home.is_empty() || home[0] != '/')
            env->raise("ArgumentError", "non-absolute home");

        if (string.length() == 1 + user.length()) {
            return home;
        } else {
            assert(string.length() > 1 + user.length());
            return String::format("{}{}", home, &string[1 + user.length()]);
        }
    };

    auto path_string_object = ioutil::convert_using_to_path(env, path);
    auto path_string = path_string_object->string();

    path_string = expand_tilde(std::move(path_string));

    auto fs_path = std::filesystem::path(path_string.c_str());
    if (fs_path.is_relative() && dir_arg && !dir_arg->is_nil()) {
        auto dir = dir_arg.value();
        dir = ioutil::convert_using_to_path(env, dir);
        path_string = expand_tilde(String::format("{}/{}", dir.as_string()->string(), path_string));
        fs_path = std::filesystem::path(path_string.c_str());
    }

    if (fs_path.string().empty())
        return StringObject::create(std::filesystem::current_path().c_str());

    if (fs_path.is_relative()) {
        try {
            fs_path = std::filesystem::absolute(fs_path);
        } catch (std::filesystem::filesystem_error &) {
            env->raise("ArgumentError", "error expanding path 1");
        }
    }

    std::filesystem::path expanded;
    try {
        expanded = fs_path.lexically_normal();
    } catch (std::filesystem::filesystem_error &) {
        env->raise("ArgumentError", "error expanding path");
    }

    auto default_external = EncodingObject::default_external();
    auto target_encoding = path_string_object->encoding();
    if (!default_external->is_compatible_with(target_encoding))
        target_encoding->raise_compatibility_error(env, default_external);

    auto expanded_string = StringObject::create(expanded.c_str(), path_string_object->encoding());
    if (expanded_string->length() > 1 && expanded_string->string().last_char() == '/')
        expanded_string->truncate(expanded_string->length() - 1);

    return expanded_string;
}

Value FileObject::flock(Env *env, Value locking_constant) {
    const auto locking_constant_int = IntegerMethods::convert_to_nat_int_t(env, locking_constant);

    do {
        auto result = ::flock(fileno(env), locking_constant_int);
        if (result == 0)
            return Value::integer(0);
        if (errno == EWOULDBLOCK)
            return Value::False();
    } while (errno == EINTR);

    env->raise_errno();
}

void FileObject::unlink(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    int result = ::unlink(path.as_string()->c_str());
    if (result != 0)
        env->raise_errno();
}

Value FileObject::unlink(Env *env, Args &&args) {
    for (size_t i = 0; i < args.size(); ++i) {
        FileObject::unlink(env, args[i]);
    }
    return Value::integer(args.size());
}

// MRI defines these constants differently than the OS does in fnmatch.h
#define FNM_NOESCAPE 0x01
#define FNM_PATHNAME 0x02
#define FNM_DOTMATCH 0x04
#define FNM_CASEFOLD 0x08
#define FNM_EXTGLOB 0x10
#define FNM_SYSCASE 0
#define FNM_SHORTNAME 0

void FileObject::build_constants(Env *env, ModuleObject *fcmodule) {
    fcmodule->const_set("APPEND"_s, Value::integer(O_APPEND));
    fcmodule->const_set("RDONLY"_s, Value::integer(O_RDONLY));
    fcmodule->const_set("WRONLY"_s, Value::integer(O_WRONLY));
    fcmodule->const_set("TRUNC"_s, Value::integer(O_TRUNC));
    fcmodule->const_set("CREAT"_s, Value::integer(O_CREAT));
    fcmodule->const_set("DSYNC"_s, Value::integer(O_DSYNC));
    fcmodule->const_set("EXCL"_s, Value::integer(O_EXCL));
    fcmodule->const_set("NOCTTY"_s, Value::integer(O_NOCTTY));
    fcmodule->const_set("NOFOLLOW"_s, Value::integer(O_NOFOLLOW));
    fcmodule->const_set("NONBLOCK"_s, Value::integer(O_NONBLOCK));
    fcmodule->const_set("RDWR"_s, Value::integer(O_RDWR));
    fcmodule->const_set("SYNC"_s, Value::integer(O_SYNC));
    fcmodule->const_set("LOCK_EX"_s, Value::integer(LOCK_EX));
    fcmodule->const_set("LOCK_NB"_s, Value::integer(LOCK_NB));
    fcmodule->const_set("LOCK_SH"_s, Value::integer(LOCK_SH));
    fcmodule->const_set("LOCK_UN"_s, Value::integer(LOCK_UN));
    fcmodule->const_set("FNM_NOESCAPE"_s, Value::integer(FNM_NOESCAPE));
    fcmodule->const_set("FNM_PATHNAME"_s, Value::integer(FNM_PATHNAME));
    fcmodule->const_set("FNM_DOTMATCH"_s, Value::integer(FNM_DOTMATCH));
    fcmodule->const_set("FNM_CASEFOLD"_s, Value::integer(FNM_CASEFOLD));
    fcmodule->const_set("FNM_EXTGLOB"_s, Value::integer(FNM_EXTGLOB));
    fcmodule->const_set("FNM_SYSCASE"_s, Value::integer(FNM_SYSCASE));
    fcmodule->const_set("FNM_SHORTNAME"_s, Value::integer(FNM_SHORTNAME));
    Value null_file = StringObject::create("/dev/null", Encoding::US_ASCII);
    null_file->freeze();
    fcmodule->const_set("NULL"_s, null_file);
}

bool FileObject::exist(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    return ::stat(path.as_string()->c_str(), &sb) != -1;
}

bool FileObject::is_absolute_path(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    return path.as_string()->string()[0] == '/';
}

bool FileObject::is_file(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return S_ISREG(sb.st_mode);
}

bool FileObject::is_directory(Env *env, Value path) {
    struct stat sb;
    if (ioutil::object_stat(env, path, &sb) == -1)
        return false;
    return S_ISDIR(sb.st_mode);
}

bool FileObject::is_identical(Env *env, Value file1, Value file2) {
    file1 = ioutil::convert_using_to_path(env, file1);
    file2 = ioutil::convert_using_to_path(env, file2);
    struct stat stat1;
    struct stat stat2;
    auto result1 = ::stat(file1.as_string()->c_str(), &stat1);
    auto result2 = ::stat(file2.as_string()->c_str(), &stat2);
    if (result1 < 0) return false;
    if (result2 < 0) return false;
    if (stat1.st_dev != stat2.st_dev) return false;
    if (stat1.st_ino != stat2.st_ino) return false;
    return true;
}

bool FileObject::is_sticky(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    std::error_code ec;
    auto st = std::filesystem::status(path.as_string()->c_str(), ec);
    if (ec)
        return false;
    auto perm = st.permissions();
    return (perm & std::filesystem::perms::sticky_bit) != std::filesystem::perms::none;
}

bool FileObject::is_setgid(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return (sb.st_mode & S_ISGID);
}

bool FileObject::is_setuid(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return (sb.st_mode & S_ISUID);
}

bool FileObject::is_symlink(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::lstat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return S_ISLNK(sb.st_mode);
}

bool FileObject::is_blockdev(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return S_ISBLK(sb.st_mode);
}

bool FileObject::is_chardev(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return S_ISCHR(sb.st_mode);
}

bool FileObject::is_pipe(Env *env, Value path) {
    struct stat sb;
    path.assert_type(env, Object::Type::String, "String");
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return S_ISFIFO(sb.st_mode);
}

bool FileObject::is_socket(Env *env, Value path) {
    struct stat sb;
    path.assert_type(env, Object::Type::String, "String");
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return S_ISSOCK(sb.st_mode);
}

bool FileObject::is_readable(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    if (access(path.as_string()->c_str(), R_OK) == -1)
        return false;
    return true;
}

bool FileObject::is_readable_real(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    if (effective_uid_access(path.as_string()->c_str(), R_OK) == -1)
        return false;
    return true;
}

Value FileObject::world_readable(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return Value::nil();
    if ((sb.st_mode & (S_IROTH)) == S_IROTH) {
        auto modenum = sb.st_mode & (S_IRUSR | S_IRGRP | S_IROTH | S_IWUSR | S_IWGRP | S_IWOTH | S_IXUSR | S_IXGRP | S_IXOTH);
        return Value::integer(modenum);
    }
    return Value::nil();
}

Value FileObject::world_writable(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return Value::nil();
    if ((sb.st_mode & (S_IWOTH)) == S_IWOTH) {
        auto modenum = sb.st_mode & (S_IRUSR | S_IRGRP | S_IROTH | S_IWUSR | S_IWGRP | S_IWOTH | S_IXUSR | S_IXGRP | S_IXOTH);
        return Value::integer(modenum);
    }
    return Value::nil();
}

bool FileObject::is_writable(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    if (access(path.as_string()->c_str(), W_OK) == -1)
        return false;
    return true;
}

bool FileObject::is_writable_real(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    if (effective_uid_access(path.as_string()->c_str(), W_OK) == -1)
        return false;
    return true;
}

bool FileObject::is_executable(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    if (access(path.as_string()->c_str(), X_OK) == -1)
        return false;
    return true;
}

bool FileObject::is_executable_real(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    if (effective_uid_access(path.as_string()->c_str(), X_OK) == -1)
        return false;
    return true;
}

bool FileObject::is_grpowned(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    auto size = getgroups(0, nullptr);
    if (size < 0)
        env->raise_errno();
    // clang-tidy raises an error for `list[size]` with possible `size == 0`
    if (size == 0)
        return false;
    gid_t list[size];
    size = getgroups(size, list);
    if (size < 0)
        env->raise_errno();
    const auto egid = ::getegid();
    for (size_t i = 0; i < static_cast<size_t>(size); i++) {
        if (list[i] == egid)
            return true;
    }
    return false;
}

bool FileObject::is_owned(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return (sb.st_uid == ::geteuid());
}

bool FileObject::is_zero(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    if (::stat(path.as_string()->c_str(), &sb) == -1)
        return false;
    return (sb.st_size == 0);
}

// oddball function that is ends in '?' but is not a boolean return.
Value FileObject::is_size(Env *env, Value path) {
    struct stat sb;
    if (ioutil::object_stat(env, path, &sb) == -1)
        return Value::nil();
    if (sb.st_size == 0) // returns nil when file size is zero.
        return Value::nil();
    return Value::integer((nat_int_t)(sb.st_size));
}

Value FileObject::size(Env *env, Value path) {
    struct stat sb;
    if (ioutil::object_stat(env, path, &sb) == -1)
        env->raise_errno();
    return Value::integer((nat_int_t)(sb.st_size));
}

nat_int_t FileObject::symlink(Env *env, Value from, Value to) {
    from = ioutil::convert_using_to_path(env, from);
    to = ioutil::convert_using_to_path(env, to);
    int result = ::symlink(from.as_string()->c_str(), to.as_string()->c_str());
    if (result < 0) env->raise_errno();
    return 0;
}

nat_int_t FileObject::rename(Env *env, Value from, Value to) {
    from = ioutil::convert_using_to_path(env, from);
    to = ioutil::convert_using_to_path(env, to);
    int result = ::rename(from.as_string()->c_str(), to.as_string()->c_str());
    if (result < 0) env->raise_errno();
    return 0;
}

nat_int_t FileObject::link(Env *env, Value from, Value to) {
    from = ioutil::convert_using_to_path(env, from);
    to = ioutil::convert_using_to_path(env, to);
    int result = ::link(from.as_string()->c_str(), to.as_string()->c_str());
    if (result < 0) env->raise_errno();
    return 0;
}

nat_int_t FileObject::mkfifo(Env *env, Value path, Optional<Value> mode_arg) {
    mode_t mode = 0666;
    if (mode_arg) {
        mode_arg->assert_integer(env);
        mode = (mode_t)mode_arg->integer().to_nat_int_t();
    }
    path = ioutil::convert_using_to_path(env, path);
    int result = ::mkfifo(path.as_string()->c_str(), mode);
    if (result < 0) env->raise_errno();
    return 0;
}

Value FileObject::chmod(Env *env, Args &&args) {
    // requires mode argument, file arguments are optional
    args.ensure_argc_at_least(env, 1);
    auto mode = args[0];
    mode_t modenum = IntegerMethods::convert_to_int(env, mode);
    for (size_t i = 1; i < args.size(); ++i) {
        auto path = ioutil::convert_using_to_path(env, args[i]);
        int result = ::chmod(path->c_str(), modenum);
        if (result < 0) env->raise_errno();
    }
    // return number of files
    return Value::integer(args.size() - 1);
}

Value FileObject::chown(Env *env, Args &&args) {
    // requires uid/gid arguments, file arguments are optional
    args.ensure_argc_at_least(env, 2);
    auto uid = args.at(0);
    auto gid = args.at(1);
    uid_t uidnum = IntegerMethods::convert_to_uid(env, uid);
    gid_t gidnum = IntegerMethods::convert_to_gid(env, gid);
    for (size_t i = 2; i < args.size(); ++i) {
        auto path = ioutil::convert_using_to_path(env, args[i]);
        int result = ::chown(path->c_str(), uidnum, gidnum);
        if (result < 0) env->raise_errno();
    }
    // return number of files
    return Value::integer(args.size() - 2);
}

// Instance method (single arg)
Value FileObject::chmod(Env *env, Value mode) {
    mode_t modenum = IntegerMethods::convert_to_int(env, mode);
    auto file_desc = fileno(); // current file descriptor
    int result = ::fchmod(file_desc, modenum);
    if (result < 0) env->raise_errno();
    return Value::integer(0); // always return 0
}

// Instance method (two args)
Value FileObject::chown(Env *env, Value uid, Value gid) {
    uid_t uidnum = IntegerMethods::convert_to_uid(env, uid);
    gid_t gidnum = IntegerMethods::convert_to_gid(env, gid);
    auto file_desc = fileno(); // current file descriptor
    int result = ::fchown(file_desc, uidnum, gidnum);
    if (result < 0) env->raise_errno();
    return Value::integer(0); // always return 0
}

Value FileObject::ftype(Env *env, Value path) {
    path = ioutil::convert_using_to_path(env, path);
    std::error_code ec;
    // use symlink_status instead of status bc we do not want to follow symlinks
    auto st = std::filesystem::symlink_status(path.as_string()->c_str(), ec);
    if (ec)
        env->raise_errno(ec.value());
    switch (st.type()) {
    case std::filesystem::file_type::regular:
        return StringObject::create("file");
    case std::filesystem::file_type::directory:
        return StringObject::create("directory");
    case std::filesystem::file_type::symlink:
        return StringObject::create("link");
    case std::filesystem::file_type::block:
        return StringObject::create("blockSpecial");
    case std::filesystem::file_type::character:
        return StringObject::create("characterSpecial");
    case std::filesystem::file_type::fifo:
        return StringObject::create("fifo");
    case std::filesystem::file_type::socket:
        return StringObject::create("socket");
    default:
        return StringObject::create("unknown");
    }
}

Value FileObject::umask(Env *env, Optional<Value> mask) {
    mode_t old_mask = 0;
    if (mask) {
        mode_t mask_mode = IntegerMethods::convert_to_int(env, mask.value());
        old_mask = ::umask(mask_mode);
    } else {
        old_mask = ::umask(0);
    }
    return Value::integer(old_mask);
}

// class method
StringObject *FileObject::path(Env *env, Value pathname) {
    return ioutil::convert_using_to_path(env, pathname);
}

Value FileObject::readlink(Env *env, Value filename) {
    filename = ioutil::convert_using_to_path(env, filename);
    TM::String buf(128, '\0');
    while (true) {
        const auto size = ::readlink(filename.as_string()->c_str(), &buf[0], buf.size());
        if (size < 0)
            env->raise_errno();
        if (static_cast<size_t>(size) < buf.size())
            return StringObject::create(buf.c_str(), static_cast<size_t>(size));
        buf = TM::String(buf.size() * 2, '\0');
    }
}

Value FileObject::realpath(Env *env, Value pathname, Optional<Value> dir_arg) {
    pathname = ioutil::convert_using_to_path(env, pathname);
    if (dir_arg) {
        pathname.as_string()->prepend_char(env, '/');
        pathname.as_string()->prepend(env, { ioutil::convert_using_to_path(env, dir_arg.value()) });
    }
    char *resolved_filepath = nullptr;
    resolved_filepath = ::realpath(pathname.as_string()->c_str(), nullptr);
    if (!resolved_filepath)
        env->raise_errno();
    auto outstr = StringObject::create(resolved_filepath);
    free(resolved_filepath);
    return outstr;
}

// class method
Value FileObject::lstat(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    int result = ::lstat(path.as_string()->c_str(), &sb);
    if (result < 0) env->raise_errno(path.as_string());
    return FileStatObject::create(sb);
}

// instance method
Value FileObject::lstat(Env *env) const {
    struct stat sb;
    int result = ::stat(get_path().as_string()->c_str(), &sb);
    if (result < 0) env->raise_errno();
    return FileStatObject::create(sb);
}

Value FileObject::lutime(Env *env, Args &&args) {
    args.ensure_argc_at_least(env, 2);
    timeval tv[2];
    timeval now;
    if (gettimeofday(&now, nullptr) < 0)
        env->raise_errno();
    auto time_convert = [&](Value v, timeval &t) {
        if (v.is_nil()) {
            t = now;
        } else if (v.is_time()) {
            t.tv_sec = static_cast<time_t>(v.as_time()->to_i(env).integer().to_nat_int_t());
            t.tv_usec = static_cast<suseconds_t>(v.as_time()->usec(env).integer().to_nat_int_t());
        } else if (v.is_integer()) {
            t.tv_sec = IntegerMethods::convert_to_native_type<time_t>(env, v);
            t.tv_usec = 0;
        } else if (v.is_float()) {
            const auto tmp = v.to_f(env)->to_double();
            t.tv_sec = static_cast<time_t>(tmp);
            t.tv_usec = (tmp - t.tv_sec) * 1000000;
        } else {
            env->raise("TypeError", "can't convert {} into time", v.klass()->inspect_module());
        }
    };
    time_convert(args.at(0), tv[0]);
    time_convert(args.at(1), tv[1]);
    for (size_t i = 2; i < args.size(); i++) {
        auto filename = ioutil::convert_using_to_path(env, args.at(i));
        if (lutimes(filename->c_str(), tv) < 0)
            env->raise_errno();
    }
    return Value::integer(args.size() - 2);
}

int FileObject::truncate(Env *env, Value path, Value size) {
    path = ioutil::convert_using_to_path(env, path);
    off_t len = IntegerMethods::convert_to_int(env, size);
    if (::truncate(path.as_string()->c_str(), len) == -1) {
        env->raise_errno();
    }
    return 0;
}
int FileObject::truncate(Env *env, Value size) const { // instance method
    off_t len = IntegerMethods::convert_to_int(env, size);
    if (::ftruncate(fileno(), len) == -1) {
        env->raise_errno();
    }
    return 0;
}

// class method
Value FileObject::stat(Env *env, Value path) {
    struct stat sb;
    path = ioutil::convert_using_to_path(env, path);
    int result = ::stat(path.as_string()->c_str(), &sb);
    if (result < 0) env->raise_errno(path.as_string());
    return FileStatObject::create(sb);
}

// class methods
Value FileObject::atime(Env *env, Value path) {
    FileStatObject *statobj;
    if (path.is_io()) { // using file-descriptor
        statobj = path.as_io()->stat(env).as_file_stat();
    } else {
        path = ioutil::convert_using_to_path(env, path);
        statobj = stat(env, path).as_file_stat();
    }
    return statobj->atime(env);
}
Value FileObject::ctime(Env *env, Value path) {
    FileStatObject *statobj;
    if (path.is_io()) { // using file-descriptor
        statobj = path.as_io()->stat(env).as_file_stat();
    } else {
        path = ioutil::convert_using_to_path(env, path);
        statobj = stat(env, path).as_file_stat();
    }
    return statobj->ctime(env);
}

Value FileObject::mtime(Env *env, Value path) {
    FileStatObject *statobj;
    if (path.is_io()) { // using file-descriptor
        statobj = path.as_io()->stat(env).as_file_stat();
    } else {
        path = ioutil::convert_using_to_path(env, path);
        statobj = stat(env, path).as_file_stat();
    }
    return statobj->mtime(env);
}

Value FileObject::utime(Env *env, Args &&args) {
    args.ensure_argc_at_least(env, 2);

    TimeObject *atime, *mtime;

    if (args[0].is_nil()) {
        atime = TimeObject::create(env);
    } else if (args[0].is_time()) {
        atime = args[0].as_time();
    } else {
        atime = TimeObject::at(env, GlobalEnv::the()->Time(), args[0]);
    }
    if (args[1].is_nil()) {
        mtime = TimeObject::create(env);
    } else if (args[1].is_time()) {
        mtime = args[1].as_time();
    } else {
        mtime = TimeObject::at(env, GlobalEnv::the()->Time(), args[1]);
    }

    struct timeval ubuf[2], *ubufp = nullptr;
    ubuf[0].tv_sec = atime->to_r(env).as_rational()->to_i(env).integer().to_nat_int_t();
    ubuf[0].tv_usec = atime->usec(env).integer().to_nat_int_t();
    ubuf[1].tv_sec = mtime->to_r(env).as_rational()->to_i(env).integer().to_nat_int_t();
    ubuf[1].tv_usec = mtime->usec(env).integer().to_nat_int_t();
    ubufp = ubuf;

    for (size_t i = 2; i < args.size(); ++i) {
        Value path = args[i];
        path = ioutil::convert_using_to_path(env, path);
        if (::utimes(path.as_string()->c_str(), ubufp) != 0) {
            env->raise_errno();
        }
    }
    return Value::integer((nat_int_t)(args.size() - 2));
}

Value FileObject::atime(Env *env) { // inst method
    if (is_closed()) env->raise("IOError", "closed stream");
    return as_io()->stat(env).as_file_stat()->atime(env);
}
Value FileObject::ctime(Env *env) { // inst method
    if (is_closed()) env->raise("IOError", "closed stream");
    return as_io()->stat(env).as_file_stat()->ctime(env);
}
Value FileObject::mtime(Env *env) { // inst method
    if (is_closed()) env->raise("IOError", "closed stream");
    return as_io()->stat(env).as_file_stat()->mtime(env);
}
Value FileObject::size(Env *env) { // inst method
    if (is_closed()) env->raise("IOError", "closed stream");
    return as_io()->stat(env).as_file_stat()->size();
}

}
