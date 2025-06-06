require_relative '../fixtures/strings'

require 'yaml'

describe :yaml_load_safe, shared: true do
  it "returns a document from current io stream when io provided" do
    @test_file = tmp("yaml_test_file")
    File.open(@test_file, 'w') do |io|
      YAML.dump( ['badger', 'elephant', 'tiger'], io )
    end
    File.open(@test_file) { |yf| YAML.send(@method,  yf ) }.should == ['badger', 'elephant', 'tiger']
  ensure
    rm_r @test_file
  end

  it "loads strings" do
    strings = ["str",
               " str",
               "'str'",
               "str",
               " str",
               "'str'",
               "\"str\"",
                "\n str",
                "---  str",
                "---\nstr",
                "--- \nstr",
                "--- \n str",
                "--- 'str'"
              ]
    strings.each do |str|
      YAML.send(@method, str).should == "str"
    end
  end

  it "loads strings with chars from non-base Unicode plane" do
    # We add these strings as bytes and force the encoding for safety
    # as bugs in parsing unicode characters can obscure bugs in this
    # area.

    yaml_and_strings = {
      # "--- 🌵" => "🌵"
      [45, 45, 45, 32, 240, 159, 140, 181] =>
      [240, 159, 140, 181],
      # "--- 🌵 and some text" => "🌵 and some text"
      [45, 45, 45, 32, 240, 159, 140, 181, 32, 97, 110, 100, 32, 115, 111, 109, 101, 32, 116, 101, 120, 116] =>
      [240, 159, 140, 181, 32, 97, 110, 100, 32, 115, 111, 109, 101, 32, 116, 101, 120, 116],
      # "--- Some text 🌵 and some text" => "Some text 🌵 and some text"
      [45, 45, 45, 32, 83, 111, 109, 101, 32, 116, 101, 120, 116, 32, 240, 159, 140, 181, 32, 97, 110, 100, 32, 115, 111, 109, 101, 32, 116, 101, 120, 116] =>
      [83, 111, 109, 101, 32, 116, 101, 120, 116, 32, 240, 159, 140, 181, 32, 97, 110, 100, 32, 115, 111, 109, 101, 32, 116, 101, 120, 116]
    }
    yaml_and_strings.each do |yaml, str|
      YAML.send(@method, yaml.pack("C*").force_encoding("UTF-8")).should == str.pack("C*").force_encoding("UTF-8")
    end
  end

  it "fails on invalid keys" do
    if YAML.to_s == "Psych"
      error = Psych::SyntaxError
    else
      error = ArgumentError
    end
    -> { YAML.send(@method, "key1: value\ninvalid_key") }.should raise_error(error)
  end

  it "accepts symbols" do
    YAML.send(@method,  "--- :locked" ).should == :locked
  end

  it "accepts numbers" do
    YAML.send(@method, "47").should == 47
    YAML.send(@method, "-1").should == -1
  end

  it "accepts collections" do
    expected = ["a", "b", "c"]
    YAML.send(@method, "--- \n- a\n- b\n- c\n").should == expected
    YAML.send(@method, "--- [a, b, c]").should == expected
    YAML.send(@method, "[a, b, c]").should == expected
  end

  it "parses start markers" do
    YAML.send(@method, "---\n").should == nil
    YAML.send(@method, "--- ---\n").should == "---"
    YAML.send(@method, "--- abc").should == "abc"
  end

  it "works with block sequence shortcuts" do
    block_seq = "- - - one\n    - two\n    - three"
    YAML.send(@method, block_seq).should == [[["one", "two", "three"]]]
  end

  it "loads a symbol key that contains spaces" do
    string = ":user name: This is the user name."
    expected = { :"user name" => "This is the user name."}
    YAML.send(@method, string).should == expected
  end
end

describe :yaml_load_unsafe, shared: true do
  it "works on complex keys" do
    require 'date'
    expected = {
      [ 'Detroit Tigers', 'Chicago Cubs' ] => [ Date.new( 2001, 7, 23 ) ],
      [ 'New York Yankees', 'Atlanta Braves' ] => [ Date.new( 2001, 7, 2 ),
                                                    Date.new( 2001, 8, 12 ),
                                                    Date.new( 2001, 8, 14 ) ]
    }
    NATFIXME 'Implement YAML.unsafe_load', exception: SpecFailedException do
      YAML.send(@method, YAMLSpecs::COMPLEX_KEY_1).should == expected
    end
  end

  describe "with iso8601 timestamp" do
    it "computes the microseconds" do
      NATFIXME 'Implement YAML.unsafe_load', exception: NoMethodError, message: "undefined method 'usec' for an instance of String" do
        [ [YAML.send(@method, "2011-03-22t23:32:11.2233+01:00"),   223300],
          [YAML.send(@method, "2011-03-22t23:32:11.0099+01:00"),   9900],
          [YAML.send(@method, "2011-03-22t23:32:11.000076+01:00"), 76]
        ].should be_computed_by(:usec)
      end
    end

    it "rounds values smaller than 1 usec to 0 " do
      NATFIXME 'Implement YAML.unsafe_load', exception: NoMethodError, message: "undefined method 'usec' for an instance of String" do
        YAML.send(@method, "2011-03-22t23:32:11.000000342222+01:00").usec.should == 0
      end
    end
  end

  it "loads an OpenStruct" do
    begin
      require "ostruct"
    rescue LoadError
      skip "OpenStruct is not available"
    end
    os = OpenStruct.new("age" => 20, "name" => "John")
    loaded = YAML.send(@method, "--- !ruby/object:OpenStruct\ntable:\n  :age: 20\n  :name: John\n")
    NATFIXME 'Implement YAML.unsafe_load', exception: SpecFailedException do
      loaded.should == os
    end
  end

  it "loads a File but raise an error when used as it is uninitialized" do
    NATFIXME 'Implement YAML.unsafe_load', exception: ArgumentError, message: 'Expected key token' do
      loaded = YAML.send(@method, "--- !ruby/object:File {}\n")
      -> {
        loaded.read(1)
      }.should raise_error(IOError)
    end
  end
end
