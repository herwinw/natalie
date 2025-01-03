# -*- encoding: utf-8 -*-
require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "String#inspect" do
  it "does not return a subclass instance" do
    StringSpecs::MyString.new.inspect.should be_an_instance_of(String)
  end

  it "returns a string with special characters replaced with \\<char> notation" do
    [ ["\a", '"\\a"'],
      ["\b", '"\\b"'],
      ["\t", '"\\t"'],
      ["\n", '"\\n"'],
      ["\v", '"\\v"'],
      ["\f", '"\\f"'],
      ["\r", '"\\r"'],
      ["\e", '"\\e"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with special characters replaced with \\<char> notation for UTF-16" do
    pairs = [
      ["\a", '"\\a"'],
      ["\b", '"\\b"'],
      ["\t", '"\\t"'],
      ["\n", '"\\n"'],
      ["\v", '"\\v"'],
      ["\f", '"\\f"'],
      ["\r", '"\\r"'],
      ["\e", '"\\e"']
    ].map { |str, result| [str.encode('UTF-16LE'), result] }

    pairs.should be_computed_by(:inspect)
  end

  it "returns a string with \" and \\ escaped with a backslash" do
    [ ["\"", '"\\""'],
      ["\\", '"\\\\"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with \\#<char> when # is followed by $, @, {" do
    [ ["\#$", '"\\#$"'],
      ["\#@", '"\\#@"'],
      ["\#{", '"\\#{"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with # not escaped when followed by any other character" do
    [ ["#", '"#"'],
      ["#1", '"#1"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with printable non-alphanumeric characters unescaped" do
    [ [" ", '" "'],
      ["!", '"!"'],
      ["$", '"$"'],
      ["%", '"%"'],
      ["&", '"&"'],
      ["'", '"\'"'],
      ["(", '"("'],
      [")", '")"'],
      ["*", '"*"'],
      ["+", '"+"'],
      [",", '","'],
      ["-", '"-"'],
      [".", '"."'],
      ["/", '"/"'],
      [":", '":"'],
      [";", '";"'],
      ["<", '"<"'],
      ["=", '"="'],
      [">", '">"'],
      ["?", '"?"'],
      ["@", '"@"'],
      ["[", '"["'],
      ["]", '"]"'],
      ["^", '"^"'],
      ["_", '"_"'],
      ["`", '"`"'],
      ["{", '"{"'],
      ["|", '"|"'],
      ["}", '"}"'],
      ["~", '"~"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with numeric characters unescaped" do
    [ ["0", '"0"'],
      ["1", '"1"'],
      ["2", '"2"'],
      ["3", '"3"'],
      ["4", '"4"'],
      ["5", '"5"'],
      ["6", '"6"'],
      ["7", '"7"'],
      ["8", '"8"'],
      ["9", '"9"'],
    ].should be_computed_by(:inspect)
  end

  it "returns a string with upper-case alpha characters unescaped" do
    [ ["A", '"A"'],
      ["B", '"B"'],
      ["C", '"C"'],
      ["D", '"D"'],
      ["E", '"E"'],
      ["F", '"F"'],
      ["G", '"G"'],
      ["H", '"H"'],
      ["I", '"I"'],
      ["J", '"J"'],
      ["K", '"K"'],
      ["L", '"L"'],
      ["M", '"M"'],
      ["N", '"N"'],
      ["O", '"O"'],
      ["P", '"P"'],
      ["Q", '"Q"'],
      ["R", '"R"'],
      ["S", '"S"'],
      ["T", '"T"'],
      ["U", '"U"'],
      ["V", '"V"'],
      ["W", '"W"'],
      ["X", '"X"'],
      ["Y", '"Y"'],
      ["Z", '"Z"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with lower-case alpha characters unescaped" do
    [ ["a", '"a"'],
      ["b", '"b"'],
      ["c", '"c"'],
      ["d", '"d"'],
      ["e", '"e"'],
      ["f", '"f"'],
      ["g", '"g"'],
      ["h", '"h"'],
      ["i", '"i"'],
      ["j", '"j"'],
      ["k", '"k"'],
      ["l", '"l"'],
      ["m", '"m"'],
      ["n", '"n"'],
      ["o", '"o"'],
      ["p", '"p"'],
      ["q", '"q"'],
      ["r", '"r"'],
      ["s", '"s"'],
      ["t", '"t"'],
      ["u", '"u"'],
      ["v", '"v"'],
      ["w", '"w"'],
      ["x", '"x"'],
      ["y", '"y"'],
      ["z", '"z"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with non-printing characters replaced by \\x notation" do
    # Avoid the file encoding by computing the string with #chr.
    [ [0001.chr, '"\\x01"'],
      [0002.chr, '"\\x02"'],
      [0003.chr, '"\\x03"'],
      [0004.chr, '"\\x04"'],
      [0005.chr, '"\\x05"'],
      [0006.chr, '"\\x06"'],
      [0016.chr, '"\\x0E"'],
      [0017.chr, '"\\x0F"'],
      [0020.chr, '"\\x10"'],
      [0021.chr, '"\\x11"'],
      [0022.chr, '"\\x12"'],
      [0023.chr, '"\\x13"'],
      [0024.chr, '"\\x14"'],
      [0025.chr, '"\\x15"'],
      [0026.chr, '"\\x16"'],
      [0027.chr, '"\\x17"'],
      [0030.chr, '"\\x18"'],
      [0031.chr, '"\\x19"'],
      [0032.chr, '"\\x1A"'],
      [0034.chr, '"\\x1C"'],
      [0035.chr, '"\\x1D"'],
      [0036.chr, '"\\x1E"'],
      [0037.chr, '"\\x1F"'],
      [0177.chr, '"\\x7F"'],
      [0200.chr, '"\\x80"'],
      [0201.chr, '"\\x81"'],
      [0202.chr, '"\\x82"'],
      [0203.chr, '"\\x83"'],
      [0204.chr, '"\\x84"'],
      [0205.chr, '"\\x85"'],
      [0206.chr, '"\\x86"'],
      [0207.chr, '"\\x87"'],
      [0210.chr, '"\\x88"'],
      [0211.chr, '"\\x89"'],
      [0212.chr, '"\\x8A"'],
      [0213.chr, '"\\x8B"'],
      [0214.chr, '"\\x8C"'],
      [0215.chr, '"\\x8D"'],
      [0216.chr, '"\\x8E"'],
      [0217.chr, '"\\x8F"'],
      [0220.chr, '"\\x90"'],
      [0221.chr, '"\\x91"'],
      [0222.chr, '"\\x92"'],
      [0223.chr, '"\\x93"'],
      [0224.chr, '"\\x94"'],
      [0225.chr, '"\\x95"'],
      [0226.chr, '"\\x96"'],
      [0227.chr, '"\\x97"'],
      [0230.chr, '"\\x98"'],
      [0231.chr, '"\\x99"'],
      [0232.chr, '"\\x9A"'],
      [0233.chr, '"\\x9B"'],
      [0234.chr, '"\\x9C"'],
      [0235.chr, '"\\x9D"'],
      [0236.chr, '"\\x9E"'],
      [0237.chr, '"\\x9F"'],
      [0240.chr, '"\\xA0"'],
      [0241.chr, '"\\xA1"'],
      [0242.chr, '"\\xA2"'],
      [0243.chr, '"\\xA3"'],
      [0244.chr, '"\\xA4"'],
      [0245.chr, '"\\xA5"'],
      [0246.chr, '"\\xA6"'],
      [0247.chr, '"\\xA7"'],
      [0250.chr, '"\\xA8"'],
      [0251.chr, '"\\xA9"'],
      [0252.chr, '"\\xAA"'],
      [0253.chr, '"\\xAB"'],
      [0254.chr, '"\\xAC"'],
      [0255.chr, '"\\xAD"'],
      [0256.chr, '"\\xAE"'],
      [0257.chr, '"\\xAF"'],
      [0260.chr, '"\\xB0"'],
      [0261.chr, '"\\xB1"'],
      [0262.chr, '"\\xB2"'],
      [0263.chr, '"\\xB3"'],
      [0264.chr, '"\\xB4"'],
      [0265.chr, '"\\xB5"'],
      [0266.chr, '"\\xB6"'],
      [0267.chr, '"\\xB7"'],
      [0270.chr, '"\\xB8"'],
      [0271.chr, '"\\xB9"'],
      [0272.chr, '"\\xBA"'],
      [0273.chr, '"\\xBB"'],
      [0274.chr, '"\\xBC"'],
      [0275.chr, '"\\xBD"'],
      [0276.chr, '"\\xBE"'],
      [0277.chr, '"\\xBF"'],
      [0300.chr, '"\\xC0"'],
      [0301.chr, '"\\xC1"'],
      [0302.chr, '"\\xC2"'],
      [0303.chr, '"\\xC3"'],
      [0304.chr, '"\\xC4"'],
      [0305.chr, '"\\xC5"'],
      [0306.chr, '"\\xC6"'],
      [0307.chr, '"\\xC7"'],
      [0310.chr, '"\\xC8"'],
      [0311.chr, '"\\xC9"'],
      [0312.chr, '"\\xCA"'],
      [0313.chr, '"\\xCB"'],
      [0314.chr, '"\\xCC"'],
      [0315.chr, '"\\xCD"'],
      [0316.chr, '"\\xCE"'],
      [0317.chr, '"\\xCF"'],
      [0320.chr, '"\\xD0"'],
      [0321.chr, '"\\xD1"'],
      [0322.chr, '"\\xD2"'],
      [0323.chr, '"\\xD3"'],
      [0324.chr, '"\\xD4"'],
      [0325.chr, '"\\xD5"'],
      [0326.chr, '"\\xD6"'],
      [0327.chr, '"\\xD7"'],
      [0330.chr, '"\\xD8"'],
      [0331.chr, '"\\xD9"'],
      [0332.chr, '"\\xDA"'],
      [0333.chr, '"\\xDB"'],
      [0334.chr, '"\\xDC"'],
      [0335.chr, '"\\xDD"'],
      [0336.chr, '"\\xDE"'],
      [0337.chr, '"\\xDF"'],
      [0340.chr, '"\\xE0"'],
      [0341.chr, '"\\xE1"'],
      [0342.chr, '"\\xE2"'],
      [0343.chr, '"\\xE3"'],
      [0344.chr, '"\\xE4"'],
      [0345.chr, '"\\xE5"'],
      [0346.chr, '"\\xE6"'],
      [0347.chr, '"\\xE7"'],
      [0350.chr, '"\\xE8"'],
      [0351.chr, '"\\xE9"'],
      [0352.chr, '"\\xEA"'],
      [0353.chr, '"\\xEB"'],
      [0354.chr, '"\\xEC"'],
      [0355.chr, '"\\xED"'],
      [0356.chr, '"\\xEE"'],
      [0357.chr, '"\\xEF"'],
      [0360.chr, '"\\xF0"'],
      [0361.chr, '"\\xF1"'],
      [0362.chr, '"\\xF2"'],
      [0363.chr, '"\\xF3"'],
      [0364.chr, '"\\xF4"'],
      [0365.chr, '"\\xF5"'],
      [0366.chr, '"\\xF6"'],
      [0367.chr, '"\\xF7"'],
      [0370.chr, '"\\xF8"'],
      [0371.chr, '"\\xF9"'],
      [0372.chr, '"\\xFA"'],
      [0373.chr, '"\\xFB"'],
      [0374.chr, '"\\xFC"'],
      [0375.chr, '"\\xFD"'],
      [0376.chr, '"\\xFE"'],
      [0377.chr, '"\\xFF"']
    ].should be_computed_by(:inspect)
  end

  it "returns a string with a NUL character replaced by \\x notation" do
    0.chr.inspect.should == '"\\x00"'
  end

  it "uses \\x notation for broken UTF-8 sequences" do
    "\xF0\x9F".inspect.should == '"\\xF0\\x9F"'
  end

  it "works for broken US-ASCII strings" do
    s = "©".dup.force_encoding("US-ASCII")
    s.inspect.should == '"\xC2\xA9"'
  end

  describe "when default external is UTF-8" do
    before :each do
      @extenc, Encoding.default_external = Encoding.default_external, Encoding::UTF_8
    end

    after :each do
      Encoding.default_external = @extenc
    end

    it "returns a string with non-printing characters replaced by \\u notation for Unicode strings" do
      [ [0001.chr('utf-8'), '"\u0001"'],
        [0002.chr('utf-8'), '"\u0002"'],
        [0003.chr('utf-8'), '"\u0003"'],
        [0004.chr('utf-8'), '"\u0004"'],
        [0005.chr('utf-8'), '"\u0005"'],
        [0006.chr('utf-8'), '"\u0006"'],
        [0016.chr('utf-8'), '"\u000E"'],
        [0017.chr('utf-8'), '"\u000F"'],
        [0020.chr('utf-8'), '"\u0010"'],
        [0021.chr('utf-8'), '"\u0011"'],
        [0022.chr('utf-8'), '"\u0012"'],
        [0023.chr('utf-8'), '"\u0013"'],
        [0024.chr('utf-8'), '"\u0014"'],
        [0025.chr('utf-8'), '"\u0015"'],
        [0026.chr('utf-8'), '"\u0016"'],
        [0027.chr('utf-8'), '"\u0017"'],
        [0030.chr('utf-8'), '"\u0018"'],
        [0031.chr('utf-8'), '"\u0019"'],
        [0032.chr('utf-8'), '"\u001A"'],
        [0034.chr('utf-8'), '"\u001C"'],
        [0035.chr('utf-8'), '"\u001D"'],
        [0036.chr('utf-8'), '"\u001E"'],
        [0037.chr('utf-8'), '"\u001F"'],
        [0177.chr('utf-8'), '"\u007F"'],
        [0200.chr('utf-8'), '"\u0080"'],
        [0201.chr('utf-8'), '"\u0081"'],
        [0202.chr('utf-8'), '"\u0082"'],
        [0203.chr('utf-8'), '"\u0083"'],
        [0204.chr('utf-8'), '"\u0084"'],
        [0206.chr('utf-8'), '"\u0086"'],
        [0207.chr('utf-8'), '"\u0087"'],
        [0210.chr('utf-8'), '"\u0088"'],
        [0211.chr('utf-8'), '"\u0089"'],
        [0212.chr('utf-8'), '"\u008A"'],
        [0213.chr('utf-8'), '"\u008B"'],
        [0214.chr('utf-8'), '"\u008C"'],
        [0215.chr('utf-8'), '"\u008D"'],
        [0216.chr('utf-8'), '"\u008E"'],
        [0217.chr('utf-8'), '"\u008F"'],
        [0220.chr('utf-8'), '"\u0090"'],
        [0221.chr('utf-8'), '"\u0091"'],
        [0222.chr('utf-8'), '"\u0092"'],
        [0223.chr('utf-8'), '"\u0093"'],
        [0224.chr('utf-8'), '"\u0094"'],
        [0225.chr('utf-8'), '"\u0095"'],
        [0226.chr('utf-8'), '"\u0096"'],
        [0227.chr('utf-8'), '"\u0097"'],
        [0230.chr('utf-8'), '"\u0098"'],
        [0231.chr('utf-8'), '"\u0099"'],
        [0232.chr('utf-8'), '"\u009A"'],
        [0233.chr('utf-8'), '"\u009B"'],
        [0234.chr('utf-8'), '"\u009C"'],
        [0235.chr('utf-8'), '"\u009D"'],
        [0236.chr('utf-8'), '"\u009E"'],
        [0237.chr('utf-8'), '"\u009F"'],
      ].should be_computed_by(:inspect)
    end

    it "returns a string with a NUL character replaced by \\u notation" do
      0.chr('utf-8').inspect.should == '"\\u0000"'
    end

    it "returns a string with extended characters for Unicode strings" do
      [ [0240.chr('utf-8'), '" "'],
        [0241.chr('utf-8'), '"¡"'],
        [0242.chr('utf-8'), '"¢"'],
        [0243.chr('utf-8'), '"£"'],
        [0244.chr('utf-8'), '"¤"'],
        [0245.chr('utf-8'), '"¥"'],
        [0246.chr('utf-8'), '"¦"'],
        [0247.chr('utf-8'), '"§"'],
        [0250.chr('utf-8'), '"¨"'],
        [0251.chr('utf-8'), '"©"'],
        [0252.chr('utf-8'), '"ª"'],
        [0253.chr('utf-8'), '"«"'],
        [0254.chr('utf-8'), '"¬"'],
        [0255.chr('utf-8'), '"­"'],
        [0256.chr('utf-8'), '"®"'],
        [0257.chr('utf-8'), '"¯"'],
        [0260.chr('utf-8'), '"°"'],
        [0261.chr('utf-8'), '"±"'],
        [0262.chr('utf-8'), '"²"'],
        [0263.chr('utf-8'), '"³"'],
        [0264.chr('utf-8'), '"´"'],
        [0265.chr('utf-8'), '"µ"'],
        [0266.chr('utf-8'), '"¶"'],
        [0267.chr('utf-8'), '"·"'],
        [0270.chr('utf-8'), '"¸"'],
        [0271.chr('utf-8'), '"¹"'],
        [0272.chr('utf-8'), '"º"'],
        [0273.chr('utf-8'), '"»"'],
        [0274.chr('utf-8'), '"¼"'],
        [0275.chr('utf-8'), '"½"'],
        [0276.chr('utf-8'), '"¾"'],
        [0277.chr('utf-8'), '"¿"'],
        [0300.chr('utf-8'), '"À"'],
        [0301.chr('utf-8'), '"Á"'],
        [0302.chr('utf-8'), '"Â"'],
        [0303.chr('utf-8'), '"Ã"'],
        [0304.chr('utf-8'), '"Ä"'],
        [0305.chr('utf-8'), '"Å"'],
        [0306.chr('utf-8'), '"Æ"'],
        [0307.chr('utf-8'), '"Ç"'],
        [0310.chr('utf-8'), '"È"'],
        [0311.chr('utf-8'), '"É"'],
        [0312.chr('utf-8'), '"Ê"'],
        [0313.chr('utf-8'), '"Ë"'],
        [0314.chr('utf-8'), '"Ì"'],
        [0315.chr('utf-8'), '"Í"'],
        [0316.chr('utf-8'), '"Î"'],
        [0317.chr('utf-8'), '"Ï"'],
        [0320.chr('utf-8'), '"Ð"'],
        [0321.chr('utf-8'), '"Ñ"'],
        [0322.chr('utf-8'), '"Ò"'],
        [0323.chr('utf-8'), '"Ó"'],
        [0324.chr('utf-8'), '"Ô"'],
        [0325.chr('utf-8'), '"Õ"'],
        [0326.chr('utf-8'), '"Ö"'],
        [0327.chr('utf-8'), '"×"'],
        [0330.chr('utf-8'), '"Ø"'],
        [0331.chr('utf-8'), '"Ù"'],
        [0332.chr('utf-8'), '"Ú"'],
        [0333.chr('utf-8'), '"Û"'],
        [0334.chr('utf-8'), '"Ü"'],
        [0335.chr('utf-8'), '"Ý"'],
        [0336.chr('utf-8'), '"Þ"'],
        [0337.chr('utf-8'), '"ß"'],
        [0340.chr('utf-8'), '"à"'],
        [0341.chr('utf-8'), '"á"'],
        [0342.chr('utf-8'), '"â"'],
        [0343.chr('utf-8'), '"ã"'],
        [0344.chr('utf-8'), '"ä"'],
        [0345.chr('utf-8'), '"å"'],
        [0346.chr('utf-8'), '"æ"'],
        [0347.chr('utf-8'), '"ç"'],
        [0350.chr('utf-8'), '"è"'],
        [0351.chr('utf-8'), '"é"'],
        [0352.chr('utf-8'), '"ê"'],
        [0353.chr('utf-8'), '"ë"'],
        [0354.chr('utf-8'), '"ì"'],
        [0355.chr('utf-8'), '"í"'],
        [0356.chr('utf-8'), '"î"'],
        [0357.chr('utf-8'), '"ï"'],
        [0360.chr('utf-8'), '"ð"'],
        [0361.chr('utf-8'), '"ñ"'],
        [0362.chr('utf-8'), '"ò"'],
        [0363.chr('utf-8'), '"ó"'],
        [0364.chr('utf-8'), '"ô"'],
        [0365.chr('utf-8'), '"õ"'],
        [0366.chr('utf-8'), '"ö"'],
        [0367.chr('utf-8'), '"÷"'],
        [0370.chr('utf-8'), '"ø"'],
        [0371.chr('utf-8'), '"ù"'],
        [0372.chr('utf-8'), '"ú"'],
        [0373.chr('utf-8'), '"û"'],
        [0374.chr('utf-8'), '"ü"'],
        [0375.chr('utf-8'), '"ý"'],
        [0376.chr('utf-8'), '"þ"'],
        [0377.chr('utf-8'), '"ÿ"']
      ].should be_computed_by(:inspect)
    end
  end

  describe "when the string's encoding is different than the result's encoding" do
    describe "and the string's encoding is ASCII-compatible but the characters are non-ASCII" do
      it "returns a string with the non-ASCII characters replaced by \\x notation" do
        NATFIXME 'returns a string with the non-ASCII characters replaced by \\x notation', exception: SpecFailedException do
          "\u{3042}".encode("EUC-JP").inspect.should == '"\\x{A4A2}"'
        end
      end
    end

    describe "and the string has both ASCII-compatible and ASCII-incompatible chars" do
      it "returns a string with the non-ASCII characters replaced by \\u notation" do
        NATFIXME 'returns a string with the non-ASCII characters replaced by \\u notation', exception: SpecFailedException do
          "hello привет".encode("utf-16le").inspect.should == '"hello \\u043F\\u0440\\u0438\\u0432\\u0435\\u0442"'
        end
      end
    end
  end
end
