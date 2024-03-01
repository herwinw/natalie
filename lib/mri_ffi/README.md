To compile the shared library:

   ruby extconf.rb
   make
   ruby call-methods-ruby.rb

To compile the C example script, add these lines to the bottom of the generated Makefile:

    call-methods-c: call-methods-c.c $(TARGET_SO)
      $(ECHO) Creating executable $@
      $(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ $(LIBPATH) $(DLDFLAGS) $(LOCAL_LIBS) $(LIBS) $<


Ensure to use tabs as indentation (that's how Makefiles work)
