require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "IO#lineno" do
  before :each do
    @io = IOSpecs.io_fixture "lines.txt"
  end

  after :each do
    @io.close if @io
  end

  it "raises an IOError on a closed stream" do
    -> { IOSpecs.closed_io.lineno }.should raise_error(IOError)
  end

  it "raises an IOError on a write-only stream" do
    name = tmp("io_lineno.txt")
    begin
      File.open(name, 'w') do |f|
        -> { f.lineno }.should raise_error(IOError)
      end
    ensure
      rm_r name
    end
  end

  it "raises an IOError on a duplexed stream with the read side closed" do
    NATFIXME 'Implement IO#close_read', exception: NoMethodError, message: /undefined method [`']close_read' for an instance of IO/ do
      cmd = platform_is(:windows) ? 'rem' : 'cat'
      IO.popen(cmd, 'r+') do |p|
        p.close_read
        -> { p.lineno }.should raise_error(IOError)
      end
    end
  end

  it "returns the current line number" do
    @io.lineno.should == 0

    count = 0
    while @io.gets
      @io.lineno.should == count += 1
    end

    @io.rewind
    @io.lineno.should == 0
  end
end

describe "IO#lineno=" do
  before :each do
    @io = IOSpecs.io_fixture "lines.txt"
  end

  after :each do
    @io.close if @io
  end

  it "raises an IOError on a closed stream" do
    -> { IOSpecs.closed_io.lineno = 5 }.should raise_error(IOError)
  end

  it "raises an IOError on a write-only stream" do
    name = tmp("io_lineno.txt")
    begin
      File.open(name, 'w') do |f|
        -> { f.lineno = 0 }.should raise_error(IOError)
      end
    ensure
      rm_r name
    end
  end

  it "raises an IOError on a duplexed stream with the read side closed" do
    NATFIXME 'Implement IO#close_read', exception: NoMethodError, message: /undefined method [`']close_read' for an instance of IO/ do
      cmd = platform_is(:windows) ? 'rem' : 'cat'
      IO.popen(cmd, 'r+') do |p|
        p.close_read
        -> { p.lineno = 0 }.should raise_error(IOError)
      end
    end
  end

  it "calls #to_int on a non-numeric argument" do
    obj = mock('123')
    obj.should_receive(:to_int).and_return(123)

    @io.lineno = obj
    @io.lineno.should == 123
  end

  it "truncates a Float argument" do
    @io.lineno = 1.5
    @io.lineno.should == 1

    @io.lineno = 92233.72036854775808
    @io.lineno.should == 92233
  end

  it "raises TypeError if cannot convert argument to Integer implicitly" do
    -> { @io.lineno = "1" }.should raise_error(TypeError, 'no implicit conversion of String into Integer')
    -> { @io.lineno = nil }.should raise_error(TypeError, 'no implicit conversion from nil to integer')
  end

  it "does not accept Integers that don't fit in a C int" do
    -> { @io.lineno = 2**32 }.should raise_error(RangeError)
  end

  it "sets the current line number to the given value" do
    @io.lineno = count = 500

    while @io.gets
      @io.lineno.should == count += 1
    end

    @io.rewind
    @io.lineno.should == 0
  end

  it "does not change $." do
    original_line = $.
    numbers = [-2**30, -2**16, -2**8, -100, -10, -1, 0, 1, 10, 2**8, 2**16, 2**30]
    numbers.each do |num|
      @io.lineno = num
      @io.lineno.should == num
      $..should == original_line
    end
  end

  it "does not change $. until next read" do
    $. = 0
    $..should == 0

    @io.lineno = count = 500
    $..should == 0

    while @io.gets
      $..should == count += 1
    end
  end
end
