// Source: https://silverhammermba.github.io/emberb/embed/

#include <ruby.h>

int main(int argc, char* argv[])
{
  /* construct the VM */
  ruby_init();

  /* Ruby goes here */
  ruby_init_loadpath();
  rb_require("./methods.so");

  VALUE str = rb_str_new_cstr("Hello, world!");
  (void)rb_funcall(str, rb_intern("my_fixed_args_method"), 2, Qtrue, INT2NUM(1234));

  /* destruct the VM */
  return ruby_cleanup(0);
}

