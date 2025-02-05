require_relative '../../../spec_helper'
require "tmpdir"

describe "Dir.mktmpdir when passed no arguments" do
  after :each do
    Dir.rmdir @tmpdir if File.directory? @tmpdir
  end

  # NATFIXME: Fix the stub! method, this now removes the method for the
  # duration of this spec.
  xit "returns the path to the created tmp-dir" do
    Dir.stub!(:mkdir)
    Dir.should_receive(:tmpdir).and_return("/tmp")
    @tmpdir = Dir.mktmpdir
    @tmpdir.should =~ /^\/tmp\//
  end

  it "creates a new writable directory in the path provided by Dir.tmpdir" do
    Dir.should_receive(:tmpdir).and_return(tmp(""))
    @tmpdir = Dir.mktmpdir
    File.directory?(@tmpdir).should be_true
    File.writable?(@tmpdir).should be_true
  end
end

# NATFIXME: Skip for now, we don't support the block, which means we don't
# clean up the tempdir and get errors from the spec runner
xdescribe "Dir.mktmpdir when passed a block" do
  before :each do
    @real_tmp_root = tmp('')
    Dir.stub!(:tmpdir).and_return(@real_tmp_root)
    FileUtils.stub!(:remove_entry)
    FileUtils.stub!(:remove_entry_secure)
  end

  after :each do
    Dir.rmdir @tmpdir if File.directory? @tmpdir
  end

  it "yields the path to the passed block" do
    Dir.stub!(:mkdir)
    called = nil
    Dir.mktmpdir do |path|
      @tmpdir = path
      called = true
      path.should.start_with?(@real_tmp_root)
    end
    called.should be_true
  end

  it "creates the tmp-dir before yielding" do
    Dir.should_receive(:tmpdir).and_return(tmp(""))
    Dir.mktmpdir do |path|
      @tmpdir = path
      File.directory?(path).should be_true
      File.writable?(path).should be_true
    end
  end

  it "removes the tmp-dir after executing the block" do
    Dir.stub!(:mkdir)
    Dir.mktmpdir do |path|
      @tmpdir = path
      FileUtils.should_receive(:remove_entry).with(path)
    end
  end

  it "returns the blocks return value" do
    Dir.stub!(:mkdir)
    result = Dir.mktmpdir do |path|
      @tmpdir = path
      :test
    end
    result.should equal(:test)
  end
end

describe "Dir.mktmpdir when passed [String]" do
  before :each do
    Dir.stub!(:mkdir)
    Dir.stub!(:tmpdir).and_return("/tmp")
  end

  after :each do
    Dir.rmdir @tmpdir if File.directory? @tmpdir
  end

  it "uses the passed String as a prefix to the tmp-directory" do
    prefix = "before"
    NATFIXME 'Support arguments', exception: ArgumentError, message: 'TODO: Support arguments' do
      @tmpdir = Dir.mktmpdir(prefix)
      @tmpdir.should =~ /^\/tmp\/#{prefix}/
    end
  end
end

describe "Dir.mktmpdir when passed [Array]" do
  before :each do
    Dir.stub!(:mkdir)
    Dir.stub!(:tmpdir).and_return("/tmp")
    FileUtils.stub!(:remove_entry_secure)
  end

  after :each do
    Dir.rmdir @tmpdir if File.directory? @tmpdir
  end

  it "uses the first element of the passed Array as a prefix and the second element as a suffix to the tmp-directory" do
    prefix = "before"
    suffix = "after"

    NATFIXME 'Support arguments', exception: ArgumentError, message: 'TODO: Support arguments' do
      @tmpdir = Dir.mktmpdir([prefix, suffix])
      @tmpdir.should =~ /#{suffix}$/
    end
  end
end

describe "Dir.mktmpdir when passed [Object]" do
  it "raises an ArgumentError" do
    -> { Dir.mktmpdir(Object.new) }.should raise_error(ArgumentError)
    -> { Dir.mktmpdir(:symbol) }.should raise_error(ArgumentError)
    -> { Dir.mktmpdir(10) }.should raise_error(ArgumentError)
  end
end
