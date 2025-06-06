# encoding: binary

describe :regexp_new, shared: true do
  it "requires one argument and creates a new regular expression object" do
    Regexp.send(@method, '').is_a?(Regexp).should == true
  end

  it "works by default for subclasses with overridden #initialize" do
    class RegexpSpecsSubclass < Regexp
      def initialize(*args)
        super
        @args = args
      end

      attr_accessor :args
    end

    class RegexpSpecsSubclassTwo < Regexp; end

    RegexpSpecsSubclass.send(@method, "hi").should be_kind_of(RegexpSpecsSubclass)
    RegexpSpecsSubclass.send(@method, "hi").args.first.should == "hi"

    RegexpSpecsSubclassTwo.send(@method, "hi").should be_kind_of(RegexpSpecsSubclassTwo)
  end
end

describe :regexp_new_non_string_or_regexp, shared: true do
  it "calls #to_str method for non-String/Regexp argument" do
    obj = Object.new
    def obj.to_str() "a" end

    Regexp.send(@method, obj).should == /a/
  end

  it "raises TypeError if there is no #to_str method for non-String/Regexp argument" do
    obj = Object.new
    -> { Regexp.send(@method, obj) }.should raise_error(TypeError, "no implicit conversion of Object into String")

    -> { Regexp.send(@method, 1) }.should raise_error(TypeError, "no implicit conversion of Integer into String")
    -> { Regexp.send(@method, 1.0) }.should raise_error(TypeError, "no implicit conversion of Float into String")
    -> { Regexp.send(@method, :symbol) }.should raise_error(TypeError, "no implicit conversion of Symbol into String")
    -> { Regexp.send(@method, []) }.should raise_error(TypeError, "no implicit conversion of Array into String")
  end

  it "raises TypeError if #to_str returns non-String value" do
    obj = Object.new
    def obj.to_str() [] end

    -> { Regexp.send(@method, obj) }.should raise_error(TypeError, /can't convert Object to String/)
  end
end

describe :regexp_new_string, shared: true do
  it "uses the String argument as an unescaped literal to construct a Regexp object" do
    Regexp.send(@method, "^hi{2,3}fo.o$").should == /^hi{2,3}fo.o$/
  end

  it "raises a RegexpError when passed an incorrect regexp" do
    -> { Regexp.send(@method, "^[$", 0) }.should raise_error(RegexpError, Regexp.new(Regexp.escape("premature end of char-class: /^[$/")))
  end

  it "does not set Regexp options if only given one argument" do
    r = Regexp.send(@method, 'Hi')
    (r.options & Regexp::IGNORECASE).should == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end
  end

  it "does not set Regexp options if second argument is nil or false" do
    r = Regexp.send(@method, 'Hi', nil)
    (r.options & Regexp::IGNORECASE).should == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end

    r = Regexp.send(@method, 'Hi', false)
    (r.options & Regexp::IGNORECASE).should == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end
  end

  it "sets options from second argument if it is true" do
    r = Regexp.send(@method, 'Hi', true)
    (r.options & Regexp::IGNORECASE).should_not == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end
  end

  it "sets options from second argument if it is one of the Integer option constants" do
    r = Regexp.send(@method, 'Hi', Regexp::IGNORECASE)
    (r.options & Regexp::IGNORECASE).should_not == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end

    r = Regexp.send(@method, 'Hi', Regexp::MULTILINE)
    (r.options & Regexp::IGNORECASE).should == 0
    (r.options & Regexp::MULTILINE).should_not == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end

    not_supported_on :opal do
      r = Regexp.send(@method, 'Hi', Regexp::EXTENDED)
      (r.options & Regexp::IGNORECASE).should == 0
      (r.options & Regexp::MULTILINE).should == 0
      (r.options & Regexp::EXTENDED).should_not == 1
    end
  end

  it "accepts an Integer of two or more options ORed together as the second argument" do
    r = Regexp.send(@method, 'Hi', Regexp::IGNORECASE | Regexp::EXTENDED)
    (r.options & Regexp::IGNORECASE).should_not == 0
    (r.options & Regexp::MULTILINE).should == 0
    (r.options & Regexp::EXTENDED).should_not == 0
  end

  it "does not try to convert the second argument to Integer with #to_int method call" do
    ScratchPad.clear
    obj = Object.new
    def obj.to_int() ScratchPad.record(:called) end

    -> {
      Regexp.send(@method, "Hi", obj)
    }.should complain(/expected true or false as ignorecase/, {verbose: true})

    ScratchPad.recorded.should == nil
  end

  it "warns any non-Integer, non-nil, non-false second argument" do
    r = nil
    -> {
      r = Regexp.send(@method, 'Hi', Object.new)
    }.should complain(/expected true or false as ignorecase/, {verbose: true})
    (r.options & Regexp::IGNORECASE).should_not == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end
  end

  it "accepts a String of supported flags as the second argument" do
    r = Regexp.send(@method, 'Hi', 'i')
    (r.options & Regexp::IGNORECASE).should_not == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end

    r = Regexp.send(@method, 'Hi', 'imx')
    (r.options & Regexp::IGNORECASE).should_not == 0
    (r.options & Regexp::MULTILINE).should_not == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should_not == 0
    end

    r = Regexp.send(@method, 'Hi', 'mimi')
    (r.options & Regexp::IGNORECASE).should_not == 0
    (r.options & Regexp::MULTILINE).should_not == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end

    r = Regexp.send(@method, 'Hi', '')
    (r.options & Regexp::IGNORECASE).should == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end
  end

  it "raises an Argument error if the second argument contains unsupported chars" do
    -> { Regexp.send(@method, 'Hi', 'e') }.should raise_error(ArgumentError, "unknown regexp option: e")
    -> { Regexp.send(@method, 'Hi', 'n') }.should raise_error(ArgumentError, "unknown regexp option: n")
    -> { Regexp.send(@method, 'Hi', 's') }.should raise_error(ArgumentError, "unknown regexp option: s")
    -> { Regexp.send(@method, 'Hi', 'u') }.should raise_error(ArgumentError, "unknown regexp option: u")
    -> { Regexp.send(@method, 'Hi', 'j') }.should raise_error(ArgumentError, "unknown regexp option: j")
    -> { Regexp.send(@method, 'Hi', 'mjx') }.should raise_error(ArgumentError, /unknown regexp option: mjx\b/)
  end

  describe "with escaped characters" do
    it "raises a Regexp error if there is a trailing backslash" do
      -> { Regexp.send(@method, "\\") }.should raise_error(RegexpError, Regexp.new(Regexp.escape("too short escape sequence: /\\/")))
    end

    it "does not raise a Regexp error if there is an escaped trailing backslash" do
      -> { Regexp.send(@method, "\\\\") }.should_not raise_error(RegexpError)
    end

    it "accepts a backspace followed by a character" do
      Regexp.send(@method, "\\N").should == /#{"\x5c"+"N"}/
    end

    it "accepts a one-digit octal value" do
      Regexp.send(@method, "\0").should == /#{"\x00"}/
    end

    it "accepts a two-digit octal value" do
      Regexp.send(@method, "\11").should == /#{"\x09"}/
    end

    it "accepts a one-digit hexadecimal value" do
      Regexp.send(@method, "\x9n").should == /#{"\x09n"}/
    end

    it "accepts a two-digit hexadecimal value" do
      Regexp.send(@method, "\x23").should == /#{"\x23"}/
    end

    it "interprets a digit following a two-digit hexadecimal value as a character" do
      Regexp.send(@method, "\x420").should == /#{"\x420"}/
    end

    it "raises a RegexpError if \\x is not followed by any hexadecimal digits" do
      -> { Regexp.send(@method, "\\" + "xn") }.should raise_error(RegexpError, Regexp.new(Regexp.escape("invalid hex escape: /\\xn/")))
    end

    it "accepts an escaped string interpolation" do
      Regexp.send(@method, "\#{abc}").should == /#{"\#{abc}"}/
    end

    it "accepts '\\n'" do
      Regexp.send(@method, "\n").should == /#{"\x0a"}/
    end

    it "accepts '\\t'" do
      Regexp.send(@method, "\t").should == /#{"\x09"}/
    end

    it "accepts '\\r'" do
      Regexp.send(@method, "\r").should == /#{"\x0d"}/
    end

    it "accepts '\\f'" do
      Regexp.send(@method, "\f").should == /#{"\x0c"}/
    end

    it "accepts '\\v'" do
      Regexp.send(@method, "\v").should == /#{"\x0b"}/
    end

    it "accepts '\\a'" do
      Regexp.send(@method, "\a").should == /#{"\x07"}/
    end

    it "accepts '\\e'" do
      Regexp.send(@method, "\e").should == /#{"\x1b"}/
    end

    it "accepts '\\C-\\n'" do
      Regexp.send(@method, "\C-\n").should == /#{"\x0a"}/
    end

    it "accepts '\\C-\\t'" do
      Regexp.send(@method, "\C-\t").should == /#{"\x09"}/
    end

    it "accepts '\\C-\\r'" do
      Regexp.send(@method, "\C-\r").should == /#{"\x0d"}/
    end

    it "accepts '\\C-\\f'" do
      Regexp.send(@method, "\C-\f").should == /#{"\x0c"}/
    end

    it "accepts '\\C-\\v'" do
      Regexp.send(@method, "\C-\v").should == /#{"\x0b"}/
    end

    it "accepts '\\C-\\a'" do
      Regexp.send(@method, "\C-\a").should == /#{"\x07"}/
    end

    it "accepts '\\C-\\e'" do
      Regexp.send(@method, "\C-\e").should == /#{"\x1b"}/
    end

    it "accepts multiple consecutive '\\' characters" do
      Regexp.send(@method, "\\\\\\N").should == /#{"\\\\\\"+"N"}/
    end

    it "accepts characters and escaped octal digits" do
      Regexp.send(@method, "abc\076").should == /#{"abc\x3e"}/
    end

    it "accepts escaped octal digits and characters" do
      Regexp.send(@method, "\076abc").should == /#{"\x3eabc"}/
    end

    it "accepts characters and escaped hexadecimal digits" do
      Regexp.send(@method, "abc\x42").should == /#{"abc\x42"}/
    end

    it "accepts escaped hexadecimal digits and characters" do
      Regexp.send(@method, "\x3eabc").should == /#{"\x3eabc"}/
    end

    it "accepts escaped hexadecimal and octal digits" do
      Regexp.send(@method, "\061\x42").should == /#{"\x31\x42"}/
    end

    it "accepts \\u{H} for a single Unicode codepoint" do
      Regexp.send(@method, "\u{f}").should == /#{"\x0f"}/
    end

    it "accepts \\u{HH} for a single Unicode codepoint" do
      Regexp.send(@method, "\u{7f}").should == /#{"\x7f"}/
    end

    it "accepts \\u{HHH} for a single Unicode codepoint" do
      Regexp.send(@method, "\u{07f}").should == /#{"\x7f"}/
    end

    it "accepts \\u{HHHH} for a single Unicode codepoint" do
      Regexp.send(@method, "\u{0000}").should == /#{"\x00"}/
    end

    it "accepts \\u{HHHHH} for a single Unicode codepoint" do
      Regexp.send(@method, "\u{00001}").should == /#{"\x01"}/
    end

    it "accepts \\u{HHHHHH} for a single Unicode codepoint" do
      Regexp.send(@method, "\u{000000}").should == /#{"\x00"}/
    end

    it "accepts characters followed by \\u{HHHH}" do
      Regexp.send(@method, "abc\u{3042}").should == /#{"abc\u3042"}/
    end

    it "accepts \\u{HHHH} followed by characters" do
      Regexp.send(@method, "\u{3042}abc").should == /#{"\u3042abc"}/
    end

    it "accepts escaped hexadecimal digits followed by \\u{HHHH}" do
      Regexp.send(@method, "\x42\u{3042}").should == /#{"\x42\u3042"}/
    end

    it "accepts escaped octal digits followed by \\u{HHHH}" do
      Regexp.send(@method, "\056\u{3042}").should == /#{"\x2e\u3042"}/
    end

    it "accepts a combination of escaped octal and hexadecimal digits and \\u{HHHH}" do
      Regexp.send(@method, "\056\x42\u{3042}\x52\076").should == /#{"\x2e\x42\u3042\x52\x3e"}/
    end

    it "accepts \\uHHHH for a single Unicode codepoint" do
      Regexp.send(@method, "\u3042").should == /#{"\u3042"}/
    end

    it "accepts characters followed by \\uHHHH" do
      Regexp.send(@method, "abc\u3042").should == /#{"abc\u3042"}/
    end

    it "accepts \\uHHHH followed by characters" do
      Regexp.send(@method, "\u3042abc").should == /#{"\u3042abc"}/
    end

    it "accepts escaped hexadecimal digits followed by \\uHHHH" do
      Regexp.send(@method, "\x42\u3042").should == /#{"\x42\u3042"}/
    end

    it "accepts escaped octal digits followed by \\uHHHH" do
      Regexp.send(@method, "\056\u3042").should == /#{"\x2e\u3042"}/
    end

    it "accepts a combination of escaped octal and hexadecimal digits and \\uHHHH" do
      Regexp.send(@method, "\056\x42\u3042\x52\076").should == /#{"\x2e\x42\u3042\x52\x3e"}/
    end

    it "accepts a multiple byte character which need not be escaped" do
      Regexp.send(@method, "\�").should == /#{"�"}/
    end

    it "raises a RegexpError if less than four digits are given for \\uHHHH" do
      -> { Regexp.send(@method, "\\" + "u304") }.should raise_error(RegexpError, Regexp.new(Regexp.escape("invalid Unicode escape: /\\u304/")))
    end

    it "raises a RegexpError if the \\u{} escape is empty" do
      -> { Regexp.send(@method, "\\" + "u{}") }.should raise_error(RegexpError, Regexp.new(Regexp.escape("invalid Unicode list: /\\u{}/")))
    end

    it "raises a RegexpError if the \\u{} escape contains non hexadecimal digits" do
      -> { Regexp.send(@method, "\\" + "u{abcX}") }.should raise_error(RegexpError, Regexp.new(Regexp.escape("invalid Unicode list: /\\u{abcX}/")))
    end

    it "raises a RegexpError if more than six hexadecimal digits are given" do
      -> { Regexp.send(@method, "\\" + "u{0ffffff}") }.should raise_error(RegexpError, Regexp.new(Regexp.escape("invalid Unicode range: /\\u{0ffffff}/")))
    end

    it "returns a Regexp with US-ASCII encoding if only 7-bit ASCII characters are present regardless of the input String's encoding" do
      Regexp.send(@method, "abc").encoding.should == Encoding::US_ASCII
    end

    it "returns a Regexp with source String having US-ASCII encoding if only 7-bit ASCII characters are present regardless of the input String's encoding" do
      NATFIXME "returns a Regexp with source String having US-ASCII encoding if only 7-bit ASCII characters are present regardless of the input String's encoding", exception: SpecFailedException do
        Regexp.send(@method, "abc").source.encoding.should == Encoding::US_ASCII
      end
    end

    it "returns a Regexp with US-ASCII encoding if UTF-8 escape sequences using only 7-bit ASCII are present" do
      Regexp.send(@method, "\u{61}").encoding.should == Encoding::US_ASCII
    end

    it "returns a Regexp with source String having US-ASCII encoding if UTF-8 escape sequences using only 7-bit ASCII are present" do
      NATFIXME "returns a Regexp with source String having US-ASCII encoding if UTF-8 escape sequences using only 7-bit ASCII are present", exception: SpecFailedException do
        Regexp.send(@method, "\u{61}").source.encoding.should == Encoding::US_ASCII
      end
    end

    it "returns a Regexp with UTF-8 encoding if any UTF-8 escape sequences outside 7-bit ASCII are present" do
      Regexp.send(@method, "\u{ff}").encoding.should == Encoding::UTF_8
    end

    it "returns a Regexp with source String having UTF-8 encoding if any UTF-8 escape sequences outside 7-bit ASCII are present" do
      Regexp.send(@method, "\u{ff}").source.encoding.should == Encoding::UTF_8
    end

    it "returns a Regexp with the input String's encoding" do
      str = "\x82\xa0".dup.force_encoding(Encoding::Shift_JIS)
      Regexp.send(@method, str).encoding.should == Encoding::Shift_JIS
    end

    it "returns a Regexp with source String having the input String's encoding" do
      str = "\x82\xa0".dup.force_encoding(Encoding::Shift_JIS)
      Regexp.send(@method, str).source.encoding.should == Encoding::Shift_JIS
    end
  end
end

describe :regexp_new_string_binary, shared: true do
  describe "with escaped characters" do
    it "accepts a three-digit octal value" do
      Regexp.send(@method, "\315").should == /#{"\xcd"}/
    end

    it "interprets a digit following a three-digit octal value as a character" do
      Regexp.send(@method, "\3762").should == /#{"\xfe2"}/
    end

    it "accepts '\\M-\\n'" do
      Regexp.send(@method, "\M-\n").should == /#{"\x8a"}/
    end

    it "accepts '\\M-\\t'" do
      Regexp.send(@method, "\M-\t").should == /#{"\x89"}/
    end

    it "accepts '\\M-\\r'" do
      Regexp.send(@method, "\M-\r").should == /#{"\x8d"}/
    end

    it "accepts '\\M-\\f'" do
      Regexp.send(@method, "\M-\f").should == /#{"\x8c"}/
    end

    it "accepts '\\M-\\v'" do
      Regexp.send(@method, "\M-\v").should == /#{"\x8b"}/
    end

    it "accepts '\\M-\\a'" do
      Regexp.send(@method, "\M-\a").should == /#{"\x87"}/
    end

    it "accepts '\\M-\\e'" do
      Regexp.send(@method, "\M-\e").should == /#{"\x9b"}/
    end

    it "accepts '\\M-\\C-\\n'" do
      Regexp.send(@method, "\M-\C-\n").should == /#{"\x8a"}/
    end

    it "accepts '\\M-\\C-\\t'" do
      Regexp.send(@method, "\M-\C-\t").should == /#{"\x89"}/
    end

    it "accepts '\\M-\\C-\\r'" do
      Regexp.send(@method, "\M-\C-\r").should == /#{"\x8d"}/
    end

    it "accepts '\\M-\\C-\\f'" do
      Regexp.send(@method, "\M-\C-\f").should == /#{"\x8c"}/
    end

    it "accepts '\\M-\\C-\\v'" do
      Regexp.send(@method, "\M-\C-\v").should == /#{"\x8b"}/
    end

    it "accepts '\\M-\\C-\\a'" do
      Regexp.send(@method, "\M-\C-\a").should == /#{"\x87"}/
    end

    it "accepts '\\M-\\C-\\e'" do
      Regexp.send(@method, "\M-\C-\e").should == /#{"\x9b"}/
    end
  end
end

describe :regexp_new_regexp, shared: true do
  it "uses the argument as a literal to construct a Regexp object" do
    Regexp.send(@method, /^hi{2,3}fo.o$/).should == /^hi{2,3}fo.o$/
  end

  it "preserves any options given in the Regexp literal" do
    (Regexp.send(@method, /Hi/i).options & Regexp::IGNORECASE).should_not == 0
    (Regexp.send(@method, /Hi/m).options & Regexp::MULTILINE).should_not == 0
    not_supported_on :opal do
      (Regexp.send(@method, /Hi/x).options & Regexp::EXTENDED).should_not == 0
    end

    not_supported_on :opal do
      r = Regexp.send @method, /Hi/imx
      (r.options & Regexp::IGNORECASE).should_not == 0
      (r.options & Regexp::MULTILINE).should_not == 0
      (r.options & Regexp::EXTENDED).should_not == 0
    end

    r = Regexp.send @method, /Hi/
    (r.options & Regexp::IGNORECASE).should == 0
    (r.options & Regexp::MULTILINE).should == 0
    not_supported_on :opal do
      (r.options & Regexp::EXTENDED).should == 0
    end
  end

  it "does not honour options given as additional arguments" do
    r = nil
    -> {
      r = Regexp.send @method, /hi/, Regexp::IGNORECASE
    }.should complain(/flags ignored/)
    (r.options & Regexp::IGNORECASE).should == 0
  end

  not_supported_on :opal do
    it "sets the encoding to UTF-8 if the Regexp literal has the 'u' option" do
      Regexp.send(@method, /Hi/u).encoding.should == Encoding::UTF_8
    end

    it "sets the encoding to EUC-JP if the Regexp literal has the 'e' option" do
      NATFIXME "sets the encoding to EUC-JP if the Regexp literal has the 'e' option", exception: SpecFailedException do
        Regexp.send(@method, /Hi/e).encoding.should == Encoding::EUC_JP
      end
    end

    it "sets the encoding to Windows-31J if the Regexp literal has the 's' option" do
      NATFIXME 'Add Windows-31J encoding', exception: NameError, message: 'uninitialized constant Encoding::Windows_31J' do
        Regexp.send(@method, /Hi/s).encoding.should == Encoding::Windows_31J
      end
    end

    it "sets the encoding to US-ASCII if the Regexp literal has the 'n' option and the source String is ASCII only" do
      Regexp.send(@method, /Hi/n).encoding.should == Encoding::US_ASCII
    end
  end
end
