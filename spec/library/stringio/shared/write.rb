describe :stringio_write, shared: true do
  before :each do
    @io = StringIO.new(+'12345')
  end

  it "tries to convert the passed Object to a String using #to_s" do
    obj = mock("to_s")
    obj.should_receive(:to_s).and_return("to_s")
    @io.send(@method, obj)
    @io.string.should == "to_s5"
  end
end

describe :stringio_write_string, shared: true do
  before :each do
    @io = StringIO.new(+'12345')
  end

  # TODO: RDoc says that #write appends at the current position.
  it "writes the passed String at the current buffer position" do
    @io.pos = 2
    @io.send(@method, 'x').should == 1
    @io.string.should == '12x45'
    @io.send(@method, 7).should == 1
    @io.string.should == '12x75'
  end

  it "pads self with \\000 when the current position is after the end" do
    @io.pos = 8
    @io.send(@method, 'x')
    @io.string.should == "12345\000\000\000x"
    @io.send(@method, 9)
    @io.string.should == "12345\000\000\000x9"
  end

  it "returns the number of bytes written" do
    @io.send(@method, '').should == 0
    @io.send(@method, nil).should == 0
    str = "1" * 100
    @io.send(@method, str).should == 100
  end

  it "updates self's position" do
    @io.send(@method, 'test')
    @io.pos.should eql(4)
  end

  it "handles concurrent writes correctly" do
    @io = StringIO.new
    n = 8
    go = false
    threads = n.times.map { |i|
      Thread.new {
        Thread.pass until go
        @io.write i.to_s
      }
    }
    go = true
    threads.each(&:join)
    @io.string.size.should == n.times.map(&:to_s).join.size
  end

  it "handles writing non-ASCII UTF-8 after seek" do
    @io.binmode
    @io << "\x80"
    @io.pos = 0
    @io << "\x81"
    @io.string.should == "\x812345".b
  end

  it "handles writing with position < buffer size" do
    @io.pos = 2
    @io.write "abc"
    @io.string.should == "12abc"

    @io.pos = 2
    @io.write "de"
    @io.string.should == "12dec"

    @io.pos = 2
    @io.write "fghi"
    @io.string.should == "12fghi"
  end

  it "transcodes the given string when the external encoding is set and neither is BINARY" do
    utf8_str = "hello"
    io = StringIO.new.set_encoding(Encoding::UTF_16BE)
    io.external_encoding.should == Encoding::UTF_16BE

    io.send(@method, utf8_str)

    expected = [0, 104, 0, 101, 0, 108, 0, 108, 0, 111] # UTF-16BE bytes for "hello"
    NATFIXME 'transcodes the given string when the external encoding is set and neither is BINARY', exception: SpecFailedException do
      io.string.bytes.should == expected
    end
  end

  it "does not transcode the given string when the external encoding is set and the string encoding is BINARY" do
    str = "été_".b
    io = StringIO.new.set_encoding(Encoding::UTF_16BE)
    io.external_encoding.should == Encoding::UTF_16BE

    io.send(@method, str)

    io.string.bytes.should == str.bytes
  end
end

describe :stringio_write_not_writable, shared: true do
  it "raises an IOError" do
    io = StringIO.new(+"test", "r")
    -> { io.send(@method, "test") }.should raise_error(IOError)

    io = StringIO.new(+"test")
    io.close_write
    -> { io.send(@method, "test") }.should raise_error(IOError)
  end
end

describe :stringio_write_append, shared: true do
  before :each do
    @io = StringIO.new(+"example", "a")
  end

  it "appends the passed argument to the end of self" do
    @io.send(@method, ", just testing")
    @io.string.should == "example, just testing"

    @io.send(@method, " and more testing")
    @io.string.should == "example, just testing and more testing"
  end

  it "correctly updates self's position" do
    @io.send(@method, ", testing")
    @io.pos.should eql(16)
  end
end
