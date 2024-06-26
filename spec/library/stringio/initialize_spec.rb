require_relative '../../spec_helper'
require 'stringio'

describe "StringIO#initialize when passed [Object, mode]" do
  before :each do
    @io = StringIO.allocate
  end

  it "uses the passed Object as the StringIO backend" do
    @io.send(:initialize, str = "example", "r")
    @io.string.should equal(str)
  end

  it "sets the mode based on the passed mode" do
    io = StringIO.allocate
    io.send(:initialize, +"example", "r")
    io.closed_read?.should be_false
    io.closed_write?.should be_true

    io = StringIO.allocate
    io.send(:initialize, +"example", "rb")
    io.closed_read?.should be_false
    io.closed_write?.should be_true

    io = StringIO.allocate
    io.send(:initialize, +"example", "r+")
    io.closed_read?.should be_false
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "rb+")
    io.closed_read?.should be_false
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "w")
    io.closed_read?.should be_true
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "wb")
    io.closed_read?.should be_true
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "w+")
    io.closed_read?.should be_false
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "wb+")
    io.closed_read?.should be_false
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "a")
    io.closed_read?.should be_true
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "ab")
    io.closed_read?.should be_true
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "a+")
    io.closed_read?.should be_false
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", "ab+")
    io.closed_read?.should be_false
    io.closed_write?.should be_false
  end

  it "allows passing the mode as an Integer" do
    io = StringIO.allocate
    io.send(:initialize, +"example", IO::RDONLY)
    io.closed_read?.should be_false
    io.closed_write?.should be_true

    io = StringIO.allocate
    io.send(:initialize, +"example", IO::RDWR)
    io.closed_read?.should be_false
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", IO::WRONLY)
    io.closed_read?.should be_true
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", IO::WRONLY | IO::TRUNC)
    io.closed_read?.should be_true
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", IO::RDWR | IO::TRUNC)
    io.closed_read?.should be_false
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", IO::WRONLY | IO::APPEND)
    io.closed_read?.should be_true
    io.closed_write?.should be_false

    io = StringIO.allocate
    io.send(:initialize, +"example", IO::RDWR | IO::APPEND)
    io.closed_read?.should be_false
    io.closed_write?.should be_false
  end

  it "raises a FrozenError when passed a frozen String in truncate mode as StringIO backend" do
    io = StringIO.allocate
    -> { io.send(:initialize, "example".freeze, IO::TRUNC) }.should raise_error(FrozenError)
  end

  it "tries to convert the passed mode to a String using #to_str" do
    obj = mock('to_str')
    obj.should_receive(:to_str).and_return("r")
    @io.send(:initialize, +"example", obj)

    @io.closed_read?.should be_false
    @io.closed_write?.should be_true
  end

  it "raises an Errno::EACCES error when passed a frozen string with a write-mode" do
    (str = "example").freeze
    -> { @io.send(:initialize, str, "r+") }.should raise_error(Errno::EACCES)
    -> { @io.send(:initialize, str, "w") }.should raise_error(Errno::EACCES)
    -> { @io.send(:initialize, str, "a") }.should raise_error(Errno::EACCES)
  end

  it "truncates all the content if passed w mode" do
    io = StringIO.allocate
    source = +"example".encode(Encoding::ISO_8859_1);

    io.send(:initialize, source, "w")

    NATFIXME 'it truncates all the content if passed w mode', exception: SpecFailedException do
      io.string.should.empty?
    end
    io.string.encoding.should == Encoding::ISO_8859_1
  end

  it "truncates all the content if passed IO::TRUNC mode" do
    io = StringIO.allocate
    source = +"example".encode(Encoding::ISO_8859_1);

    io.send(:initialize, source, IO::TRUNC)

    io.string.should.empty?
    io.string.encoding.should == Encoding::ISO_8859_1
  end
end

describe "StringIO#initialize when passed [Object]" do
  before :each do
    @io = StringIO.allocate
  end

  it "uses the passed Object as the StringIO backend" do
    @io.send(:initialize, str = "example")
    @io.string.should equal(str)
  end

  it "sets the mode to read-write if the string is mutable" do
    @io.send(:initialize, +"example")
    @io.closed_read?.should be_false
    @io.closed_write?.should be_false
  end

  it "sets the mode to read if the string is frozen" do
    @io.send(:initialize, -"example")
    @io.closed_read?.should be_false
    @io.closed_write?.should be_true
  end

  it "tries to convert the passed Object to a String using #to_str" do
    obj = mock('to_str')
    obj.should_receive(:to_str).and_return("example")
    @io.send(:initialize, obj)
    @io.string.should == "example"
  end

  it "automatically sets the mode to read-only when passed a frozen string" do
    (str = "example").freeze
    @io.send(:initialize, str)
    @io.closed_read?.should be_false
    @io.closed_write?.should be_true
  end
end

# NOTE: Synchronise with core/io/new_spec.rb (core/io/shared/new.rb)
describe "StringIO#initialize when passed keyword arguments" do
  it "sets the mode based on the passed :mode option" do
    io = StringIO.new("example", mode: "r")
    io.closed_read?.should be_false
    io.closed_write?.should be_true
  end

  it "accepts a mode argument set to nil with a valid :mode option" do
    @io = StringIO.new(+'', nil, mode: "w")
    @io.write("foo").should == 3
  end

  it "accepts a mode argument with a :mode option set to nil" do
    @io = StringIO.new(+'', "w", mode: nil)
    @io.write("foo").should == 3
  end

  it "sets binmode from :binmode option" do
    @io = StringIO.new(+'', 'w', binmode: true)
    @io.external_encoding.to_s.should == "ASCII-8BIT" # #binmode? isn't implemented in StringIO
  end

  it "does not set binmode from false :binmode" do
    @io = StringIO.new(+'', 'w', binmode: false)
    @io.external_encoding.to_s.should == "UTF-8" # #binmode? isn't implemented in StringIO
  end
end

# NOTE: Synchronise with core/io/new_spec.rb (core/io/shared/new.rb)
describe "StringIO#initialize when passed keyword arguments and error happens" do
  it "raises an error if passed encodings two ways" do
    -> {
      @io = StringIO.new(+'', 'w:ISO-8859-1', encoding: 'ISO-8859-1')
    }.should raise_error(ArgumentError)
    -> {
      @io = StringIO.new(+'', 'w:ISO-8859-1', external_encoding: 'ISO-8859-1')
    }.should raise_error(ArgumentError)
    -> {
      @io = StringIO.new(+'', 'w:ISO-8859-1:UTF-8', internal_encoding: 'ISO-8859-1')
    }.should raise_error(ArgumentError)
  end

  it "raises an error if passed matching binary/text mode two ways" do
    -> {
      @io = StringIO.new(+'', "wb", binmode: true)
    }.should raise_error(ArgumentError)
    -> {
      @io = StringIO.new(+'', "wt", textmode: true)
    }.should raise_error(ArgumentError)

    -> {
      @io = StringIO.new(+'', "wb", textmode: false)
    }.should raise_error(ArgumentError)
    -> {
      @io = StringIO.new(+'', "wt", binmode: false)
    }.should raise_error(ArgumentError)
  end

  it "raises an error if passed conflicting binary/text mode two ways" do
    -> {
      @io = StringIO.new(+'', "wb", binmode: false)
    }.should raise_error(ArgumentError)
    -> {
      @io = StringIO.new(+'', "wt", textmode: false)
    }.should raise_error(ArgumentError)

    -> {
      @io = StringIO.new(+'', "wb", textmode: true)
    }.should raise_error(ArgumentError)
    -> {
      @io = StringIO.new(+'', "wt", binmode: true)
    }.should raise_error(ArgumentError)
  end

  it "raises an error when trying to set both binmode and textmode" do
    -> {
      @io = StringIO.new(+'', "w", textmode: true, binmode: true)
    }.should raise_error(ArgumentError)
    -> {
      @io = StringIO.new(+'', File::Constants::WRONLY, textmode: true, binmode: true)
    }.should raise_error(ArgumentError)
  end
end

describe "StringIO#initialize when passed no arguments" do
  before :each do
    @io = StringIO.allocate
  end

  it "is private" do
    StringIO.should have_private_instance_method(:initialize)
  end

  it "sets the mode to read-write" do
    @io.send(:initialize)
    @io.closed_read?.should be_false
    @io.closed_write?.should be_false
  end

  it "uses an empty String as the StringIO backend" do
    @io.send(:initialize)
    @io.string.should == ""
  end
end

describe "StringIO#initialize sets" do
  before :each do
    @external = Encoding.default_external
    @internal = Encoding.default_internal
    Encoding.default_external = Encoding::ISO_8859_2
    Encoding.default_internal = Encoding::ISO_8859_2
  end

  after :each do
    Encoding.default_external = @external
    Encoding.default_internal = @internal
  end

  it "the encoding to Encoding.default_external when passed no arguments" do
    io = StringIO.new
    io.external_encoding.should == Encoding::ISO_8859_2
    io.string.encoding.should == Encoding::ISO_8859_2
  end

  it "the encoding to the encoding of the String when passed a String" do
    s = ''.dup.force_encoding(Encoding::EUC_JP)
    io = StringIO.new(s)
    io.string.encoding.should == Encoding::EUC_JP
  end

  it "the #external_encoding to the encoding of the String when passed a String" do
    s = ''.dup.force_encoding(Encoding::EUC_JP)
    io = StringIO.new(s)
    io.external_encoding.should == Encoding::EUC_JP
  end
end
