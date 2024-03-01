# Just a bit of an experiment for now
#
# The basic premise: we should be able to run Rubygems. As long as they're written in pure Ruby, this should just be a
# case of implementing all the missing behaviour until it works. But gems may contain a part written in C, that is using
# the C runtime of MRI.
# To bridge this, this lib attempts to start an MRI runtime in our Natalie process, converts basic data structures from
# Natalie to MRI, calls the other method from within the MRI runtime, converts the result back to Natalie data and
# returns that.
# Let's see if we can get some kind of C library working. I'm currently considering
# [bubblebabble](https://github.com/ruby/ruby/tree/v3_3_0/ext/digest/bubblebabble), since that's the only part of the
# digest module we're currently missing, and the input/output is limited to strings.

require 'natalie/inline'
require 'mri_ffi.cpp'

__ld_flags__ '-lruby'
