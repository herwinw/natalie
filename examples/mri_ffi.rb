#!bin/natalie

require 'mri_ffi'

methods_lib = File.join(__dir__, "../lib/mri_ffi/methods.#{RbConfig::CONFIG['SOEXT']}")
unless File.exist?(methods_lib)
  warn("File #{methods_lib} cannot be found, please run `ruby extconf.rb && make` in that folder and try again")
  exit(1)
end

MriFfi.load_mri_extension(methods_lib)
MriFfi.my_fixed_args_method("Hello, world!", true, 1234)
MriFfi.my_fixed_args_method(false, "O hai", 4321)

# vim: ft=ruby
