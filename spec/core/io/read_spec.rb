# -*- encoding: utf-8 -*-
require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "IO.read" do
  before :each do
    @fname = tmp("io_read.txt")
    @contents = "1234567890"
    touch(@fname) { |f| f.write @contents }
  end

  after :each do
    rm_r @fname
  end

  it "reads the contents of a file" do
    IO.read(@fname).should == @contents
  end

  it "calls #to_path on non-String arguments" do
    p = mock('path')
    p.should_receive(:to_path).and_return(@fname)
    IO.read(p)
  end

  # https://bugs.ruby-lang.org/issues/19354
  it "accepts options as keyword arguments" do
    IO.read(@fname, 3, 0, mode: "r+").should == @contents[0, 3]

    -> {
      IO.read(@fname, 3, 0, {mode: "r+"})
    }.should raise_error(ArgumentError, /wrong number of arguments/)
  end

  it "accepts an empty options Hash" do
    IO.read(@fname, **{}).should == @contents
  end

  it "accepts a length, and empty options Hash" do
    IO.read(@fname, 3, **{}).should == @contents[0, 3]
  end

  it "accepts a length, offset, and empty options Hash" do
    IO.read(@fname, 3, 0, **{}).should == @contents[0, 3]
  end

  it "raises an IOError if the options Hash specifies write mode" do
    -> { IO.read(@fname, 3, 0, mode: "w") }.should raise_error(IOError)
  end

  it "raises an IOError if the options Hash specifies append only mode" do
    -> { IO.read(@fname, mode: "a") }.should raise_error(IOError)
  end

  it "reads the file if the options Hash includes read mode" do
    IO.read(@fname, mode: "r").should == @contents
  end

  it "reads the file if the options Hash includes read/write mode" do
    IO.read(@fname, mode: "r+").should == @contents
  end

  it "reads the file if the options Hash includes read/write append mode" do
    IO.read(@fname, mode: "a+").should == @contents
  end

  platform_is_not :windows do
    ruby_version_is ""..."3.3" do
      it "uses an :open_args option" do
        string = IO.read(@fname, nil, 0, open_args: ["r", nil, {encoding: Encoding::US_ASCII}])
        string.encoding.should == Encoding::US_ASCII

        string = IO.read(@fname, nil, 0, open_args: ["r", nil, {}])
        string.encoding.should == Encoding::UTF_8
      end
    end
  end

  it "disregards other options if :open_args is given" do
    NATFIXME 'open_args keyword argument', exception: ArgumentError, message: 'unknown keyword: :open_args' do
      string = IO.read(@fname,mode: "w", encoding: Encoding::UTF_32LE, open_args: ["r", encoding: Encoding::UTF_8])
      string.encoding.should == Encoding::UTF_8
    end
  end

  it "doesn't require mode to be specified in :open_args" do
    NATFIXME 'open_args keyword argument', exception: ArgumentError, message: 'unknown keyword: :open_args' do
      string = IO.read(@fname, nil, 0, open_args: [{encoding: Encoding::US_ASCII}])
      string.encoding.should == Encoding::US_ASCII
    end
  end

  it "doesn't require mode to be specified in :open_args even if flags option passed" do
    NATFIXME 'open_args keyword argument', exception: ArgumentError, message: 'unknown keyword: :open_args' do
      string = IO.read(@fname, nil, 0, open_args: [{encoding: Encoding::US_ASCII, flags: File::CREAT}])
      string.encoding.should == Encoding::US_ASCII
    end
  end

  it "treats second nil argument as no length limit" do
    IO.read(@fname, nil).should == @contents
    IO.read(@fname, nil, 5).should == IO.read(@fname, @contents.length, 5)
  end

  it "treats third nil argument as 0" do
    IO.read(@fname, nil, nil).should == @contents
    IO.read(@fname, 5, nil).should == IO.read(@fname, 5, 0)
  end

  it "reads the contents of a file up to a certain size when specified" do
    IO.read(@fname, 5).should == @contents.slice(0..4)
  end

  it "reads the contents of a file from an offset of a specific size when specified" do
    IO.read(@fname, 5, 3).should == @contents.slice(3, 5)
  end

  it "returns nil at end-of-file when length is passed" do
    IO.read(@fname, 1, 10).should == nil
  end

  it "returns an empty string when reading zero bytes" do
    IO.read(@fname, 0).should == ''
  end

  it "returns a String in BINARY when passed a size" do
    IO.read(@fname, 1).encoding.should == Encoding::BINARY
    IO.read(@fname, 0).encoding.should == Encoding::BINARY
  end

  it "raises an Errno::ENOENT when the requested file does not exist" do
    rm_r @fname
    -> { IO.read @fname }.should raise_error(Errno::ENOENT)
  end

  it "raises a TypeError when not passed a String type" do
    -> { IO.read nil }.should raise_error(TypeError)
  end

  it "raises an ArgumentError when not passed a valid length" do
    -> { IO.read @fname, -1 }.should raise_error(ArgumentError)
  end

  ruby_version_is ''...'3.3' do
    it "raises an Errno::EINVAL when not passed a valid offset" do
      -> { IO.read @fname, 0, -1  }.should raise_error(Errno::EINVAL)
      -> { IO.read @fname, -1, -1 }.should raise_error(Errno::EINVAL)
    end
  end

  ruby_version_is '3.3' do
    it "raises an ArgumentError when not passed a valid offset" do
      -> { IO.read @fname, 0, -1  }.should raise_error(ArgumentError)
      -> { IO.read @fname, -1, -1 }.should raise_error(ArgumentError)
    end
  end

  it "uses the external encoding specified via the :external_encoding option" do
    str = IO.read(@fname, external_encoding: Encoding::ISO_8859_1)
    str.encoding.should == Encoding::ISO_8859_1
  end

  it "uses the external encoding specified via the :encoding option" do
    str = IO.read(@fname, encoding: Encoding::ISO_8859_1)
    str.encoding.should == Encoding::ISO_8859_1
  end

  platform_is :windows do
    it "reads the file in text mode" do
      # 0x1A is CTRL+Z and is EOF in Windows text mode.
      File.binwrite(@fname, "\x1Abbb")
      IO.read(@fname).should.empty?
    end
  end
end

describe "IO.read from a pipe" do
  it "runs the rest as a subprocess and returns the standard output" do
    cmd = "|sh -c 'echo hello'"
    platform_is :windows do
      cmd = "|cmd.exe /C echo hello"
    end
    NATFIXME 'Implement pipe in IO.read', exception: NotImplementedError, message: 'no support for pipe in IO.read' do
      suppress_warning do # https://bugs.ruby-lang.org/issues/19630
        IO.read(cmd).should == "hello\n"
      end
    end
  end

  platform_is_not :windows do
    it "opens a pipe to a fork if the rest is -" do
      NATFIXME 'Implement pipe in IO.read', exception: NotImplementedError, message: 'no support for pipe in IO.read' do
        str = nil
        suppress_warning do # https://bugs.ruby-lang.org/issues/19630
          str = IO.read("|-")
        end

        if str # parent
          str.should == "hello from child\n"
        else #child
          puts "hello from child"
          exit!
        end
      end
    end
  end

  it "reads only the specified number of bytes requested" do
    cmd = "|sh -c 'echo hello'"
    platform_is :windows do
      cmd = "|cmd.exe /C echo hello"
    end
    NATFIXME 'Implement pipe in IO.read', exception: NotImplementedError, message: 'no support for pipe in IO.read' do
      suppress_warning do # https://bugs.ruby-lang.org/issues/19630
        IO.read(cmd, 1).should == "h"
      end
    end
  end

  platform_is_not :windows do
    it "raises Errno::ESPIPE if passed an offset" do
      NATFIXME 'Implement pipe in IO.read', exception: NotImplementedError, message: 'no support for pipe in IO.read' do
        -> {
          suppress_warning do # https://bugs.ruby-lang.org/issues/19630
            IO.read("|sh -c 'echo hello'", 1, 1)
          end
        }.should raise_error(Errno::ESPIPE)
      end
    end
  end

  quarantine! do # The process tried to write to a nonexistent pipe.
    platform_is :windows do
      # TODO: It should raise Errno::ESPIPE on Windows as well
      # once https://bugs.ruby-lang.org/issues/12230 is fixed.
      it "raises Errno::EINVAL if passed an offset" do
        -> {
          suppress_warning do # https://bugs.ruby-lang.org/issues/19630
            IO.read("|cmd.exe /C echo hello", 1, 1)
          end
        }.should raise_error(Errno::EINVAL)
      end
    end
  end

  ruby_version_is "3.3" do
    # https://bugs.ruby-lang.org/issues/19630
    it "warns about deprecation given a path with a pipe" do
      cmd = "|echo ok"
      NATFIXME 'Pipes in read', exception: NotImplementedError, message: 'no support for pipe in IO.read' do
        -> {
          IO.read(cmd)
        }.should complain(/IO process creation with a leading '\|'/)
      end
    end
  end
end

describe "IO.read on an empty file" do
  before :each do
    @fname = tmp("io_read_empty.txt")
    touch(@fname)
  end

  after :each do
    rm_r @fname
  end

  it "returns nil when length is passed" do
    IO.read(@fname, 1).should == nil
  end

  it "returns an empty string when no length is passed" do
    IO.read(@fname).should == ""
  end
end

describe "IO#read" do

  before :each do
    @fname = tmp("io_read.txt")
    @contents = "1234567890"
    touch(@fname) { |f| f.write @contents }

    @io = open @fname, "r+"
  end

  after :each do
    @io.close
    rm_r @fname
  end

  it "can be read from consecutively" do
    @io.read(1).should == '1'
    @io.read(2).should == '23'
    @io.read(3).should == '456'
    @io.read(4).should == '7890'
  end

  it "treats first nil argument as no length limit" do
    @io.read(nil).should == @contents
  end

  it "raises an ArgumentError when not passed a valid length" do
    -> { @io.read(-1) }.should raise_error(ArgumentError)
  end

  it "clears the output buffer if there is nothing to read" do
    @io.pos = 10

    buf = +'non-empty string'

    @io.read(10, buf).should == nil

    buf.should == ''

    buf = +'non-empty string'

    @io.read(nil, buf).should == ""

    buf.should == ''

    buf = +'non-empty string'

    @io.read(0, buf).should == ""

    NATFIXME 'clears the output buffer if there is nothing to read', exception: SpecFailedException do
      buf.should == ''
    end
  end

  it "raise FrozenError if the output buffer is frozen" do
    @io.read
    NATFIXME 'raise FrozenError if the output buffer is frozen', exception: SpecFailedException do
      -> { @io.read(0, 'frozen-string'.freeze) }.should raise_error(FrozenError)
      -> { @io.read(1, 'frozen-string'.freeze) }.should raise_error(FrozenError)
      -> { @io.read(nil, 'frozen-string'.freeze) }.should raise_error(FrozenError)
    end
  end

  ruby_bug "", ""..."3.3" do
    it "raise FrozenError if the output buffer is frozen (2)" do
      @io.read
      -> { @io.read(1, ''.freeze) }.should raise_error(FrozenError)
    end
  end

  it "consumes zero bytes when reading zero bytes" do
    @io.read(0).should == ''
    @io.pos.should == 0

    @io.getc.should == '1'
  end

  it "is at end-of-file when everything has been read" do
    @io.read
    @io.should.eof?
  end

  it "reads the contents of a file" do
    @io.read.should == @contents
  end

  it "places the specified number of bytes in the buffer" do
    buf = +""
    @io.read 5, buf

    buf.should == "12345"
  end

  it "expands the buffer when too small" do
    buf = +"ABCDE"
    @io.read nil, buf

    buf.should == @contents
  end

  it "overwrites the buffer" do
    buf = +"ABCDEFGHIJ"
    @io.read nil, buf

    buf.should == @contents
  end

  it "truncates the buffer when too big" do
    buf = +"ABCDEFGHIJKLMNO"
    @io.read nil, buf
    buf.should == @contents

    @io.rewind

    buf = +"ABCDEFGHIJKLMNO"
    @io.read 5, buf
    buf.should == @contents[0..4]
  end

  it "preserves the encoding of the given buffer" do
    buffer = ''.encode(Encoding::ISO_8859_1)
    @io.read(10, buffer)

    buffer.encoding.should == Encoding::ISO_8859_1
  end

  # https://bugs.ruby-lang.org/issues/20416
  it "does not preserve the encoding of the given buffer when max length is not provided" do
    buffer = ''.encode(Encoding::ISO_8859_1)
    @io.read(nil, buffer)

    NATFIXME 'it does not preserve the encoding of the given buffer when max length is not provided', exception: SpecFailedException do
      buffer.encoding.should_not == Encoding::ISO_8859_1
    end
  end

  it "returns the given buffer" do
    buf = +""

    @io.read(nil, buf).should equal buf
  end

  it "returns the given buffer when there is nothing to read" do
    buf = +""

    @io.read
    @io.read(nil, buf).should equal buf
  end

  it "coerces the second argument to string and uses it as a buffer" do
    buf = +"ABCDE"
    obj = mock("buff")
    obj.should_receive(:to_str).any_number_of_times.and_return(buf)

    @io.read(15, obj).should_not equal obj
    buf.should == @contents
  end

  it "returns an empty string at end-of-file" do
    @io.read
    @io.read.should == ''
  end

  it "reads the contents of a file when more bytes are specified" do
    @io.read(@contents.length + 1).should == @contents
  end

  it "returns an empty string at end-of-file" do
    @io.read
    @io.read.should == ''
  end

  it "returns an empty string when the current pos is bigger than the content size" do
    @io.pos = 1000
    @io.read.should == ''
  end

  it "returns nil at end-of-file with a length" do
    @io.read
    @io.read(1).should == nil
  end

  it "with length argument returns nil when the current pos is bigger than the content size" do
    @io.pos = 1000
    @io.read(1).should == nil
  end

  it "raises IOError on closed stream" do
    -> { IOSpecs.closed_io.read }.should raise_error(IOError)
  end

  it "raises ArgumentError when length is less than 0" do
    -> { @io.read(-1) }.should raise_error(ArgumentError)
  end

  platform_is_not :windows do
    it "raises IOError when stream is closed by another thread" do
      r, w = IO.pipe
      t = Thread.new do
        begin
          r.read(1)
        rescue => e
          e
        end
      end

      Thread.pass until t.stop?
      r.close
      t.join
      t.value.should be_kind_of(IOError)
      w.close
    end
  end
end

platform_is :windows do
  describe "IO#read on Windows" do
    before :each do
      @fname = tmp("io_read.txt")
      touch(@fname, "wb") { |f| f.write "a\r\nb\r\nc" }
    end

    after :each do
      @io.close if @io
      rm_r @fname
    end

    it "normalizes line endings in text mode" do
      @io = new_io(@fname, "r")
      @io.read.should == "a\nb\nc"
    end

    it "does not normalize line endings in binary mode" do
      @io = new_io(@fname, "rb")
      @io.read.should == "a\r\nb\r\nc"
    end
  end
end

describe "IO#read" do
  before :each do
    @io = IOSpecs.io_fixture "lines.txt"
  end

  after :each do
    @io.close if @io
  end

  it "ignores unicode encoding" do
    @io.readline.should == "Voici la ligne une.\n"
    # read "Qui è"
    @io.read(5).should == "Qui " + [195].pack('C*')
  end
end

describe "IO#read in binary mode" do
  before :each do
    @internal = Encoding.default_internal
    @name = fixture __FILE__, "read_binary.txt"
  end

  after :each do
    Encoding.default_internal = @internal
  end

  it "does not transcode file contents when Encoding.default_internal is set" do
    Encoding.default_internal = "utf-8"

    result = File.open(@name, "rb") { |f| f.read }.chomp

    result.encoding.should == Encoding::BINARY
    xE2 = [226].pack('C*')
    result.should == ("abc" + xE2 + "def").force_encoding(Encoding::BINARY)
  end
end

describe "IO#read in text mode" do
  before :each do
    @external = Encoding.default_external
    @internal = Encoding.default_internal
    @name = fixture __FILE__, "read_text.txt"
  end

  after :each do
    Encoding.default_external = @external
    Encoding.default_internal = @internal
  end

  it "reads data according to the internal encoding" do
    Encoding.default_internal = "utf-8"
    Encoding.default_external = "utf-8"

    result = File.open(@name, "rt") { |f| f.read }.chomp

    result.encoding.should == Encoding::UTF_8
    result.should == "abcâdef"
  end
end

describe "IO.read with BOM" do
  it "reads a file without a bom" do
    name = fixture __FILE__, "no_bom_UTF-8.txt"
    NATFIXME 'BOM UTF-8 encoding', exception: ArgumentError, message: 'unknown encoding name - "BOM|utf-8"' do
      result = File.read(name, mode: "rb:BOM|utf-8")
      result.force_encoding("binary").should == "UTF-8\n"
    end
  end

  it "reads a file with a utf-8 bom" do
    name = fixture __FILE__, "bom_UTF-8.txt"
    NATFIXME 'BOM UTF-16 encoding', exception: ArgumentError, message: 'unknown encoding name - "BOM|utf-16le"' do
      result = File.read(name, mode: "rb:BOM|utf-16le")
      result.force_encoding("binary").should == "UTF-8\n"
    end
  end

  it "reads a file with a utf-16le bom" do
    name = fixture __FILE__, "bom_UTF-16LE.txt"
    NATFIXME 'BOM UTF-8 encoding', exception: ArgumentError, message: 'unknown encoding name - "BOM|utf-8"' do
      result = File.read(name, mode: "rb:BOM|utf-8")
      result.force_encoding("binary").should == "U\x00T\x00F\x00-\x001\x006\x00L\x00E\x00\n\x00"
    end
  end

  it "reads a file with a utf-16be bom" do
    name = fixture __FILE__, "bom_UTF-16BE.txt"
    NATFIXME 'BOM UTF-8 encoding', exception: ArgumentError, message: 'unknown encoding name - "BOM|utf-8"' do
      result = File.read(name, mode: "rb:BOM|utf-8")
      result.force_encoding("binary").should == "\x00U\x00T\x00F\x00-\x001\x006\x00B\x00E\x00\n"
    end
  end

  it "reads a file with a utf-32le bom" do
    name = fixture __FILE__, "bom_UTF-32LE.txt"
    NATFIXME 'BOM UTF-8 encoding', exception: ArgumentError, message: 'unknown encoding name - "BOM|utf-8"' do
      result = File.read(name, mode: "rb:BOM|utf-8")
      result.force_encoding("binary").should == "U\x00\x00\x00T\x00\x00\x00F\x00\x00\x00-\x00\x00\x003\x00\x00\x002\x00\x00\x00L\x00\x00\x00E\x00\x00\x00\n\x00\x00\x00"
    end
  end

  it "reads a file with a utf-32be bom" do
    name = fixture __FILE__, "bom_UTF-32BE.txt"
    NATFIXME 'BOM UTF-8 encoding', exception: ArgumentError, message: 'unknown encoding name - "BOM|utf-8"' do
      result = File.read(name, mode: "rb:BOM|utf-8")
      result.force_encoding("binary").should == "\x00\x00\x00U\x00\x00\x00T\x00\x00\x00F\x00\x00\x00-\x00\x00\x003\x00\x00\x002\x00\x00\x00B\x00\x00\x00E\x00\x00\x00\n"
    end
  end
end

describe :io_read_internal_encoding, shared: true do
  it "returns a transcoded String" do
    NATFIXME 'Encoding', exception: SpecFailedException do
      @io.read.should == "ありがとう\n"
    end
  end

  it "sets the String encoding to the internal encoding" do
    NATFIXME 'sets the String encoding to the internal encoding', exception: SpecFailedException do
      @io.read.encoding.should equal(Encoding::UTF_8)
    end
  end

  describe "when passed nil for limit" do
    it "sets the buffer to a transcoded String" do
      result = @io.read(nil, buf = +"")
      buf.should equal(result)
      NATFIXME 'Encoding', exception: SpecFailedException do
        buf.should == "ありがとう\n"
      end
    end

    it "sets the buffer's encoding to the internal encoding" do
      buf = "".dup.force_encoding Encoding::ISO_8859_1
      @io.read(nil, buf)
      NATFIXME 'Encoding', exception: SpecFailedException do
        buf.encoding.should equal(Encoding::UTF_8)
      end
    end
  end
end

describe :io_read_size_internal_encoding, shared: true do
  it "reads bytes when passed a size" do
    @io.read(2).should == [164, 162].pack('C*').force_encoding(Encoding::BINARY)
  end

  it "returns a String in BINARY when passed a size" do
    @io.read(4).encoding.should equal(Encoding::BINARY)
    @io.read(0).encoding.should equal(Encoding::BINARY)
  end

  it "does not change the buffer's encoding when passed a limit" do
    buf = "".dup.force_encoding Encoding::ISO_8859_1
    @io.read(4, buf)
    buf.should == [164, 162, 164, 234].pack('C*').force_encoding(Encoding::ISO_8859_1)
    buf.encoding.should equal(Encoding::ISO_8859_1)
  end

  it "truncates the buffer but does not change the buffer's encoding when no data remains" do
    buf = "abc".dup.force_encoding Encoding::ISO_8859_1
    @io.read

    @io.read(1, buf).should be_nil
    buf.size.should == 0
    buf.encoding.should equal(Encoding::ISO_8859_1)
  end
end

describe "IO#read" do
  describe "when IO#external_encoding and IO#internal_encoding are nil" do
    before :each do
      @name = tmp("io_read.txt")
      touch(@name) { |f| f.write "\x00\x01\x02" }
      @io = new_io @name, "r+"
    end

    after :each do
      @io.close if @io
      rm_r @name
    end

    it "sets the String encoding to Encoding.default_external" do
      @io.read.encoding.should equal(Encoding.default_external)
    end
  end

  describe "with internal encoding" do
    after :each do
      @io.close if @io
    end

    describe "not specified" do
      before :each do
        @io = IOSpecs.io_fixture "read_euc_jp.txt", "r:euc-jp"
      end

      it "does not transcode the String" do
        @io.read.should == ("ありがとう\n").encode(Encoding::EUC_JP)
      end

      it "sets the String encoding to the external encoding" do
        @io.read.encoding.should equal(Encoding::EUC_JP)
      end

      it_behaves_like :io_read_size_internal_encoding, nil
    end

    describe "specified by open mode" do
      before :each do
        @io = IOSpecs.io_fixture "read_euc_jp.txt", "r:euc-jp:utf-8"
      end

      it_behaves_like :io_read_internal_encoding, nil
      it_behaves_like :io_read_size_internal_encoding, nil
    end

    describe "specified by mode: option" do
      before :each do
        @io = IOSpecs.io_fixture "read_euc_jp.txt", mode: "r:euc-jp:utf-8"
      end

      it_behaves_like :io_read_internal_encoding, nil
      it_behaves_like :io_read_size_internal_encoding, nil
    end

    describe "specified by internal_encoding: option" do
      before :each do
        options = { mode: "r",
                    internal_encoding: "utf-8",
                    external_encoding: "euc-jp" }
        @io = IOSpecs.io_fixture "read_euc_jp.txt", options
      end

      it_behaves_like :io_read_internal_encoding, nil
      it_behaves_like :io_read_size_internal_encoding, nil
    end

    describe "specified by encoding: option" do
      before :each do
        options = { mode: "r", encoding: "euc-jp:utf-8" }
        @io = IOSpecs.io_fixture "read_euc_jp.txt", options
      end

      it_behaves_like :io_read_internal_encoding, nil
      it_behaves_like :io_read_size_internal_encoding, nil
    end
  end
end

describe "IO#read with large data" do
  before :each do
    # TODO: what is the significance of this mystery math?
    @data_size = 8096 * 2 + 1024
    @data = "*" * @data_size

    @fname = tmp("io_read.txt")
    touch(@fname) { |f| f.write @data }
  end

  after :each do
    rm_r @fname
  end

  it "reads all the data at once" do
    File.open(@fname, 'r') { |io| ScratchPad.record io.read }

    ScratchPad.recorded.size.should == @data_size
    ScratchPad.recorded.should == @data
  end

  it "reads only the requested number of bytes" do
    read_size = @data_size / 2
    File.open(@fname, 'r') { |io| ScratchPad.record io.read(read_size) }

    ScratchPad.recorded.size.should == read_size
    ScratchPad.recorded.should == @data[0, read_size]
  end
end
