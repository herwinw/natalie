# encoding: binary

require_relative '../spec_helper'
require_relative 'fixtures/class_with_class_variable'

# TODO: rewrite these horrid specs. it "are..." seriously?!

describe "Ruby character strings" do

  before :each do
    @ip = 'xxx' # used for interpolation
    $ip = 'xxx'
  end

  it "don't get interpolated when put in single quotes" do
    '#{@ip}'.should == '#{@ip}'
  end

  it 'get interpolated with #{} when put in double quotes' do
    "#{@ip}".should == 'xxx'
  end

  it "interpolate instance variables just with the # character" do
    "#@ip".should == 'xxx'
  end

  it "interpolate global variables just with the # character" do
    "#$ip".should == 'xxx'
  end

  it "interpolate class variables just with the # character" do
    object = StringSpecs::ClassWithClassVariable.new
    object.foo.should == 'xxx'
  end

  it "allows underscore as part of a variable name in a simple interpolation" do
    @my_ip = 'xxx'
    "#@my_ip".should == 'xxx'
  end

  it "does not interpolate invalid variable names" do
    "#@".should == '#@'
    "#$%".should == '#$%'
  end

  it "has characters [.(=?!# end simple # interpolation" do
    "#@ip[".should == 'xxx['
    "#@ip.".should == 'xxx.'
    "#@ip(".should == 'xxx('
    "#@ip=".should == 'xxx='
    "#@ip?".should == 'xxx?'
    "#@ip!".should == 'xxx!'
    "#@ip#@ip".should == 'xxxxxx'
  end

  it "don't get confused by partial interpolation character sequences" do
    "#@".should == '#@'
    "#@ ".should == '#@ '
    "#@@".should == '#@@'
    "#@@ ".should == '#@@ '
    "#$ ".should == '#$ '
    "#\$".should == '#$'
  end

  it "allows using non-alnum characters as string delimiters" do
    %(hey #{@ip}).should == "hey xxx"
    %[hey #{@ip}].should == "hey xxx"
    %{hey #{@ip}}.should == "hey xxx"
    %<hey #{@ip}>.should == "hey xxx"
    %!hey #{@ip}!.should == "hey xxx"
    %@hey #{@ip}@.should == "hey xxx"
    %#hey hey#.should == "hey hey"
    %%hey #{@ip}%.should == "hey xxx"
    %^hey #{@ip}^.should == "hey xxx"
    %&hey #{@ip}&.should == "hey xxx"
    %*hey #{@ip}*.should == "hey xxx"
    %-hey #{@ip}-.should == "hey xxx"
    %_hey #{@ip}_.should == "hey xxx"
    %=hey #{@ip}=.should == "hey xxx"
    %+hey #{@ip}+.should == "hey xxx"
    %~hey #{@ip}~.should == "hey xxx"
    %:hey #{@ip}:.should == "hey xxx"
    %;hey #{@ip};.should == "hey xxx"
    %"hey #{@ip}".should == "hey xxx"
    %|hey #{@ip}|.should == "hey xxx"
    %?hey #{@ip}?.should == "hey xxx"
    %/hey #{@ip}/.should == "hey xxx"
    %,hey #{@ip},.should == "hey xxx"
    %.hey #{@ip}..should == "hey xxx"

    # surprised? huh
    %'hey #{@ip}'.should == "hey xxx"
    %\hey #{@ip}\.should == "hey xxx"
    %`hey #{@ip}`.should == "hey xxx"
    %$hey #{@ip}$.should == "hey xxx"
  end

  it "using percent with 'q', stopping interpolation" do
    %q(#{@ip}).should == '#{@ip}'
  end

  it "using percent with 'Q' to interpolate" do
    %Q(#{@ip}).should == 'xxx'
  end

  # The backslashes :
  #
  # \t (tab), \n (newline), \r (carriage return), \f (form feed), \b
  # (backspace), \a (bell), \e (escape), \s (whitespace), \nnn (octal),
  # \xnn (hexadecimal), \cx (control x), \C-x (control x), \M-x (meta x),
  # \M-\C-x (meta control x)

  it "backslashes follow the same rules as interpolation" do
    "\t\n\r\f\b\a\e\s\075\x62\cx".should == "\t\n\r\f\b\a\e =b\030"
    '\t\n\r\f\b\a\e =b\030'.should == "\\t\\n\\r\\f\\b\\a\\e =b\\030"
  end

  it "calls #to_s when the object is not a String" do
    obj = mock('to_s')
    obj.stub!(:to_s).and_return('42')

    "#{obj}".should == '42'
  end

  it "calls #to_s as a private method" do
    obj = mock('to_s')
    obj.stub!(:to_s).and_return('42')

    class << obj
      private :to_s
    end

    "#{obj}".should == '42'
  end

  it "uses an internal representation when #to_s doesn't return a String" do
    obj = mock('to_s')
    obj.stub!(:to_s).and_return(42)

    # See rubyspec commit 787c132d by yugui. There is value in
    # ensuring that this behavior works. So rather than removing
    # this spec completely, the only thing that can be asserted
    # is that if you interpolate an object that fails to return
    # a String, you will still get a String and not raise an
    # exception.
    "#{obj}".should be_an_instance_of(String)
  end

  it "allows a dynamic string to parse a nested do...end block as an argument to a call without parens, interpolated" do
    NATFIXME 'eval() only works on static strings', exception: TypeError, message: 'eval() only works on static strings' do
      s = eval 'eval "#{proc do; 1; end.call}"'
      s.should == 1
    end
  end

  it "are produced from character shortcuts" do
    ?z.should == 'z'
  end

  it "are produced from control character shortcuts" do
    # Control-Z
    ?\C-z.should == "\x1A"

    # Meta-Z
    ?\M-z.should == "\xFA"

    # Meta-Control-Z
    ?\M-\C-z.should == "\x9A"
  end

  describe "Unicode escaping" do
    it "can be done with \\u and four hex digits" do
      [ ["\u0000", 0x0000],
        ["\u2020", 0x2020]
      ].should be_computed_by(:ord)
    end

    it "can be done with \\u{} and one to six hex digits" do
      [ ["\u{a}", 0xa],
        ["\u{ab}", 0xab],
        ["\u{abc}", 0xabc],
        ["\u{1abc}", 0x1abc],
        ["\u{12abc}", 0x12abc],
        ["\u{100000}", 0x100000]
      ].should be_computed_by(:ord)
    end

    # TODO: spec other source encodings
    describe "with ASCII_8BIT source encoding" do
      it "produces an ASCII string when escaping ASCII characters via \\u" do
        "\u0000".encoding.should == Encoding::BINARY
      end

      it "produces an ASCII string when escaping ASCII characters via \\u{}" do
        "\u{0000}".encoding.should == Encoding::BINARY
      end

      it "produces a UTF-8-encoded string when escaping non-ASCII characters via \\u" do
        "\u1234".encoding.should == Encoding::UTF_8
      end

      it "produces a UTF-8-encoded string when escaping non-ASCII characters via \\u{}" do
        "\u{1234}".encoding.should == Encoding::UTF_8
      end
    end
  end
end

# TODO: rewrite all specs above this

describe "Ruby String literals" do
  def str_concat
    "foo" "bar" "baz"
  end

  def long_string_literals
    "Beautiful is better than ugly." \
    "Explicit is better than implicit."
  end

  it "on a single line with spaces in between are concatenated together" do
    str_concat.should == "foobarbaz"
  end

  it "on multiple lines with newlines and backslash in between are concatenated together" do
    long_string_literals.should == "Beautiful is better than ugly.Explicit is better than implicit."
  end

  describe "with a magic frozen comment" do
    it "produce the same object each time" do
      ruby_exe(fixture(__FILE__, "freeze_magic_comment_one_literal.rb")).chomp.should == "true"
    end

    it "produce the same object for literals with the same content" do
      ruby_exe(fixture(__FILE__, "freeze_magic_comment_two_literals.rb")).chomp.should == "true"
    end

    it "produce the same object for literals with the same content in different files" do
      ruby_exe(fixture(__FILE__, "freeze_magic_comment_across_files.rb")).chomp.should == "true"
    end

    guard -> { !(eval("'test'").frozen? && "test".equal?("test")) } do
      it "produces different objects for literals with the same content in different files if the other file doesn't have the comment and String literals aren't frozen by default" do
        ruby_exe(fixture(__FILE__, "freeze_magic_comment_across_files_no_comment.rb")).chomp.should == "true"
      end
    end

    guard -> { eval("'test'").frozen? && "test".equal?("test") } do
      it "produces the same objects for literals with the same content in different files if the other file doesn't have the comment and String literals are frozen by default" do
        ruby_exe(fixture(__FILE__, "freeze_magic_comment_across_files_no_comment.rb")).chomp.should == "false"
      end
    end

    it "produce different objects for literals with the same content in different files if they have different encodings" do
      ruby_exe(fixture(__FILE__, "freeze_magic_comment_across_files_diff_enc.rb")).chomp.should == "true"
    end
  end

end

describe "Ruby String interpolation" do
  it "permits an empty expression" do
    s = "#{}" # rubocop:disable Lint/EmptyInterpolation
    s.should.empty?
    s.should_not.frozen?
  end

  it "returns a string with the source encoding by default" do
    "a#{"b"}c".encoding.should == Encoding::BINARY
    NATFIXME 'eval() only works on static strings', exception: TypeError, message: 'eval() only works on static strings' do
      eval('"a#{"b"}c"'.dup.force_encoding("us-ascii")).encoding.should == Encoding::US_ASCII
      eval("# coding: US-ASCII \n 'a#{"b"}c'").encoding.should == Encoding::US_ASCII
    end
  end

  it "returns a string with the source encoding, even if the components have another encoding" do
    a = "abc".dup.force_encoding("euc-jp")
    "#{a}".encoding.should == Encoding::BINARY

    b = "abc".encode("utf-8")
    "#{b}".encoding.should == Encoding::BINARY
  end

  it "raises an Encoding::CompatibilityError if the Encodings are not compatible" do
    a = "\u3042"
    b = "\xff".dup.force_encoding "binary"

    NATFIXME 'Raise Encoding::CompatibilityError', exception: SpecFailedException do
      -> { "#{a} #{b}" }.should raise_error(Encoding::CompatibilityError)
    end
  end

  it "creates a non-frozen String" do
    code = <<~'RUBY'
      "a#{6*7}c"
    RUBY
    NATFIXME 'eval() only works on static strings', exception: TypeError, message: 'eval() only works on static strings' do
      eval(code).should_not.frozen?
    end
  end

  it "creates a non-frozen String when # frozen-string-literal: true is used" do
    code = <<~'RUBY'
      # frozen-string-literal: true
      "a#{6*7}c"
    RUBY
    NATFIXME 'eval() only works on static strings', exception: TypeError, message: 'eval() only works on static strings' do
      eval(code).should_not.frozen?
    end
  end
end
