# Natalie

[![GitHub build status](https://github.com/natalie-lang/natalie/actions/workflows/test.yml/badge.svg)](https://github.com/natalie-lang/natalie/actions?query=workflow%3ATest+branch%3Amaster)
[![MIT License](https://img.shields.io/badge/license-MIT-blue)](https://github.com/natalie-lang/natalie/blob/master/LICENSE)
[![justforfunnoreally.dev badge](https://img.shields.io/badge/justforfunnoreally-dev-9ff)](https://justforfunnoreally.dev)

Natalie is a work-in-progress Ruby implementation.

It provides an ahead-of-time compiler using C++ and gcc/clang as the backend.
Also, the language has a REPL that performs incremental compilation.

![demo screencast](examples/demo.gif)

There is much work left to do before this is useful. Please let me know if you
want to help!

## Helping Out

Contributions are welcome! You can learn more about how I work on Natalie via
the [hacking session videos on YouTube](https://www.youtube.com/playlist?list=PLWUx_XkUoGTq-nkbhnk6PN4m109ISo5BX).

The easiest way to get started right now would be to find a method on an object
that is not yet implemented and make it yourself! Also take a look at
[good first issues](https://github.com/natalie-lang/natalie/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
(See the 'Building' and 'Running Tests' sections below for some helpful steps.)

We have a very quiet [Discord server](https://discord.gg/hnHp2tdQyn) -- come and hang out!

## Building

Natalie is tested on macOS and Ubuntu Linux. Windows is not yet supported.

Natalie requires a system Ruby (MRI) to host the compiler, for now.

Prerequisites:

- git
- autoconf
- automake
- libtool
- GNU make
- gcc or clang
- Ruby 3.2 or higher with dev headers
  - Using [rbenv](https://github.com/rbenv/rbenv) to install Ruby is preferred.
  - Installing [rbenv-aliases](https://github.com/tpope/rbenv-aliases) along with rbenv helps with matching Ruby versions like `3.2` to the latest patch release.
  - If not using rbenv or another version manager, you'll need the `ruby` and `ruby-dev` package from your system.
- ccache (optional, but recommended)
- compiledb (optional, but recommended)

Install the above prerequisites on your platform, then run:

```sh
git clone https://github.com/natalie-lang/natalie
cd natalie
rake
```

### Troubleshooting Build Errors

- **Don't use `sudo`!** If you already made that mistake, then you should `sudo rm -rf build`
  and try again.
- If you get an error about file permissions, e.g. unable to write a file to somewhere like
  `/usr/lib/ruby`, or another path that would require root, then you have a couple options:
  - Use a tool like [rbenv](https://github.com/rbenv/rbenv) to install a Ruby version in your
    home directory. Gems will also be installed there. Run `rbenv version` to see which version
    is currently selected. Run `rbenv shell` followed by a version to select that version.
  - Specify where to install gems with something like:
    ```
    mkdir -p ~/gems
    export GEM_HOME=~/gems
    ```
    You'll just have to remember to do that every time you open a new terminal tab.
- If you get an error about missing `bundler`, then your operating system probably didn't
  install it alongside Ruby. You can run `gem install bundler` to get it.

## Usage

**REPL:**

```sh
bin/natalie
```

**Run a Ruby script:**

```sh
bin/natalie examples/hello.rb
```

**Compile a file to an executable:**

```sh
bin/natalie -c hello examples/hello.rb
./hello
```

## Using With Docker

```
docker build -t natalie .                                            # build image
docker run -it --rm natalie                                          # repl
docker run -it --rm natalie -e "p 2 * 3"                             # immediate
docker run -it --rm -v$(pwd)/myfile.rb:/myfile.rb natalie /myfile.rb # execute a local rb file
docker run -it --rm --entrypoint bash natalie                        # bash prompt
```

## Running Tests

To run a test (or spec), you can run it like a normal Ruby script:

```sh
bin/natalie spec/core/string/strip_spec.rb
```

This will run the tests and tell you if there are any failures.

If you want to run all the tests that we expect to pass, you can run:

```sh
rake test
```

Lastly, if you need to run a handful of tests locally, you can use the
`test/runner.rb` helper script:

```sh
bin/natalie test/runner.rb test/natalie/if_test.rb test/natalie/loop_test.rb
```

### What's the difference between the 'spec/' and 'test/' directories?

The files in `spec/` come from the excellent [ruby/spec](https://github.com/ruby/spec)
project, which is a community-curated repo of test files that any Ruby
implementation can use to compare its conformance to what MRI (Matz's Ruby
Interpreter) does. We copy specs over as we implement the part of the language
that they cover.

Everything in `test/` is stuff we wrote while working on Natalie. These are
tests that helped us bootstrap certain parts of the language and/or weren't
covered as much as we would like by the official Ruby specs. We use this
to supplement the specs in `spec/`.

## Copyright & License

Natalie is copyright 2025, Tim Morgan and contributors. Natalie is licensed
under the MIT License; see the `LICENSE` file in this directory for the full text.

Some parts of this program are copied from other sources, and the copyright
belongs to the respective owner. Such copyright notices are either at the top of
the respective file, in the same directory with a name like `LICENSE`, or both.

| file(s)                | copyright                         | license           |
| ---------------------- | --------------------------------- | ----------------- |
| `abbrev.rb`            | Akinori Musha                     | BSD               |
| `benchmark.rb`         | Gotoken                           | BSD               |
| `bigint.{h,c}`         | 983                               | Unlicense         |
| `cgi.rb`/`cgi/*`       | Wakou Aoyama                      | BSD               |
| `crypt.{h,c}`          | The Regents of the Univ. of Cali. | BSD               |
| `delegate.rb`          | Yukihiro Matsumoto                | BSD               |
| `dtoa.c`               | David M. Gay, Lucent Technologies | custom permissive |
| `erb/util.rb`          | Masatoshi SEKI                    | BSD               |
| `ipaddr.rb`            | Hajimu Umemoto and Akinori Musha  | BSD               |
| `find.rb`              | Kazuki Tsujimoto                  | BSD               |
| `formatter.rb`         | Yukihiro Matsumoto                | BSD               |
| `linenoise`            | S. Sanfilippo and P. Noordhuis    | BSD               |
| `matrix.rb`/`matrix/*` | Marc-Andre Lafortune              | BSD               |
| `minicoro.h`           | Eduardo Bart                      | MIT               |
| `pp.rb`                | Yukihiro Matsumoto                | BSD               |
| `prettyprint.rb`       | Yukihiro Matsumoto                | BSD               |
| `shellwords.rb`        | Akinori MUSHA                     | BSD               |
| `spec/*`               | Engine Yard, Inc.                 | MIT               |
| `uri.rb`/`uri/*`       | Akira Yamada                      | BSD               |
| `version.rb`           | Engine Yard, Inc.                 | MIT               |
| `zlib`                 | Jean-loup Gailly and Mark Adler   | zlib license      |

See each file above for full copyright and license text.
