require_relative '../../spec_helper'
require_relative 'fixtures/classes'

# src.scan(/[+-]?[\d_]+\.[\d_]+(e[+-]?[\d_]+)?\b|[+-]?[\d_]+e[+-]?[\d_]+\b/i)

describe "String#to_f" do
  it "treats leading characters of self as a floating point number" do
   NATFIXME 'Reworking the parser', exception: SpecFailedException do
     "123.45e1".to_f.should == 1234.5
   end
   "45.67 degrees".to_f.should == 45.67
   "0".to_f.should == 0.0

   ".5".to_f.should == 0.5
   NATFIXME 'Reworking the parser', exception: SpecFailedException do
     ".5e1".to_f.should == 5.0
   end
   "5.".to_f.should == 5.0
   "5e".to_f.should == 5.0
   "5E".to_f.should == 5.0
  end

  it "treats special float value strings as characters" do
    "NaN".to_f.should == 0
    "Infinity".to_f.should == 0
    "-Infinity".to_f.should == 0
  end

  it "allows for varying case" do
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "123.45e1".to_f.should == 1234.5
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "123.45E1".to_f.should == 1234.5
    end
  end

  it "allows for varying signs" do
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "+123.45e1".to_f.should == +123.45e1
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "-123.45e1".to_f.should == -123.45e1
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "123.45e+1".to_f.should == 123.45e+1
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "123.45e-1".to_f.should == 123.45e-1
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "+123.45e+1".to_f.should == +123.45e+1
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "+123.45e-1".to_f.should == +123.45e-1
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "-123.45e+1".to_f.should == -123.45e+1
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "-123.45e-1".to_f.should == -123.45e-1
    end
  end

  it "allows for underscores, even in the decimal side" do
    NATFIXME 'it allows for underscores, even in the decimal side', exception: SpecFailedException do
      "1_234_567.890_1".to_f.should == 1_234_567.890_1
    end
  end

  it "returns 0 for strings with leading underscores" do
    "_9".to_f.should == 0
  end

  it "stops if the underscore is not followed or preceded by a number" do
    "1__2".to_f.should == 1.0
    "1_.2".to_f.should == 1.0
    "1._2".to_f.should == 1.0
    "1.2_e2".to_f.should == 1.2
    "1.2e_2".to_f.should == 1.2
    "1_x2".to_f.should == 1.0
    "1x_2".to_f.should == 1.0
    "+_1".to_f.should == 0.0
    "-_1".to_f.should == 0.0
  end

  it "does not allow prefixes to autodetect the base" do
    "0b10".to_f.should == 0
    "010".to_f.should == 10
    "0o10".to_f.should == 0
    "0d10".to_f.should == 0
    "0x10".to_f.should == 0
  end

  it "treats any non-numeric character other than '.', 'e' and '_' as terminals" do
    "blah".to_f.should == 0
    "1b5".to_f.should == 1
    "1d5".to_f.should == 1
    "1o5".to_f.should == 1
    "1xx5".to_f.should == 1
    "x5".to_f.should == 0
  end

  it "takes an optional sign" do
    "-45.67 degrees".to_f.should == -45.67
    "+45.67 degrees".to_f.should == 45.67
    NATFIXME 'it takes an optional sign', exception: SpecFailedException do
      "-5_5e-5_0".to_f.should == -55e-50
    end
    "-".to_f.should == 0.0
    (1.0 / "-0".to_f).to_s.should == "-Infinity"
  end

  it "treats a second 'e' as terminal" do
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "1.234e1e2".to_f.should == 1.234e1
    end
  end

  it "treats a second '.' as terminal" do
    "1.2.3".to_f.should == 1.2
  end

  it "treats a '.' after an 'e' as terminal" do
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "1.234e1.9".to_f.should == 1.234e1
    end
  end

  it "returns 0.0 if the conversion fails" do
    "bad".to_f.should == 0.0
    "thx1138".to_f.should == 0.0
  end

  it "ignores leading and trailing whitespace" do
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "  1.2".to_f.should == 1.2
    end
    "1.2  ".to_f.should == 1.2
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      " 1.2 ".to_f.should == 1.2
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "\t1.2".to_f.should == 1.2
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "\n1.2".to_f.should == 1.2
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "\v1.2".to_f.should == 1.2
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "\f1.2".to_f.should == 1.2
    end
    NATFIXME 'Reworking the parser', exception: SpecFailedException do
      "\r1.2".to_f.should == 1.2
    end
  end

  it "treats non-printable ASCII characters as terminals" do
    "\0001.2".to_f.should == 0
    "\0011.2".to_f.should == 0
    "\0371.2".to_f.should == 0
    "\1771.2".to_f.should == 0
    "\2001.2".b.to_f.should == 0
    "\3771.2".b.to_f.should == 0
  end

  ruby_version_is "3.2" do
    it "raises Encoding::CompatibilityError if String is in not ASCII-compatible encoding" do
      NATFIXME 'Add encoder to to UTF-16', exception: SpecFailedException, message: /code converter not found \(UTF-8 to UTF-16\)/ do
        -> {
          '1.2'.encode("UTF-16").to_f
        }.should raise_error(Encoding::CompatibilityError, "ASCII incompatible encoding: UTF-16")
      end
    end
  end
end
