describe :kernel_at_exit, shared: true do
  it "runs after all other code" do
    ruby_exe("#{@method} { print 5 }; print 6").should == "65"
  end

  it "runs in reverse order of registration" do
    code = "#{@method} { print 4 }; #{@method} { print 5 }; print 6; #{@method} { print 7 }"
    ruby_exe(code).should == "6754"
  end

  it "allows calling exit inside a handler" do
    code = "#{@method} { print 3 }; #{@method} { print 4; exit; print 5 }; #{@method} { print 6 }"
    NATFIXME 'it allows calling exit inside a handler', exception: SpecFailedException do
      ruby_exe(code).should == "643"
    end
  end

  it "gives access to the last raised exception - global variables $! and $@" do
    code = <<-EOC
      #{@method} {
        puts "The exception matches: \#{$! == $exception && $@ == $exception.backtrace} (message=\#{$!.message})"
      }

      begin
        raise "foo"
      rescue => $exception
        raise
      end
    EOC

    NATFIXME 'it gives access to the last raised exception - global variables $! and $@', exception: SpecFailedException do
      result = ruby_exe(code, args: "2>&1", exit_status: 1)
      result.lines.should.include?("The exception matches: true (message=foo)\n")
    end
  end

  it "gives access to an exception raised in a previous handler" do
    code = "#{@method} { print '$!.message = ' + $!.message }; #{@method} { raise 'foo' }"
    NATFIXME 'it gives access to an exception raised in a previous handler', exception: SpecFailedException do
      result = ruby_exe(code, args: "2>&1", exit_status: 1)
      result.lines.should.include?("$!.message = foo")
    end
  end

  it "both exceptions in a handler and in the main script are printed" do
    code = "#{@method} { raise 'at_exit_error' }; raise 'main_script_error'"
    NATFIXME 'it both exceptions in a handler and in the main script are printed', exception: SpecFailedException do
      result = ruby_exe(code, args: "2>&1", exit_status: 1)
      result.should.include?('at_exit_error (RuntimeError)')
      result.should.include?('main_script_error (RuntimeError)')
    end
  end

  it "decides the exit status if both at_exit and the main script raise SystemExit" do
    NATFIXME 'it decides the exit status if both at_exit and the main script raise SystemExit', exception: SpecFailedException do
      ruby_exe("#{@method} { exit 43 }; exit 42", args: "2>&1", exit_status: 43)
      $?.exitstatus.should == 43
    end
  end

  it "runs all handlers even if some raise exceptions" do
    code = "#{@method} { STDERR.puts 'last' }; #{@method} { exit 43 }; #{@method} { STDERR.puts 'first' }; exit 42"
    NATFIXME 'it runs all handlers even if some raise exceptions', exception: SpecFailedException do
      result = ruby_exe(code, args: "2>&1", exit_status: 43)
      result.should == "first\nlast\n"
      $?.exitstatus.should == 43
    end
  end

  it "runs handlers even if the main script fails to parse" do
    script = fixture(__FILE__, "#{@method}.rb")
    NATFIXME 'it runs handlers even if the main script fails to parse', exception: SpecFailedException do
      result = ruby_exe('{', options: "-r#{script}", args: "2>&1", exit_status: 1)
      $?.should_not.success?
      result.should.include?("handler ran\n")

      # it's tempting not to rely on error message and rely only on exception class name,
      # but CRuby before 3.2 doesn't print class name for syntax error
      result.should include_any_of("syntax error", "SyntaxError")
    end
  end

  it "calls the nested handler right after the outer one if a handler is nested into another handler" do
    ruby_exe(<<~ruby).should == "last\nbefore\nafter\nnested\nfirst\n"
        #{@method} { puts :first }
        #{@method} { puts :before; #{@method} { puts :nested }; puts :after };
        #{@method} { puts :last }
    ruby
  end
end
