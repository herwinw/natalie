require_relative '../spec_helper'
require 'tempfile'

describe 'Tempfile' do
  describe '.create' do
    it 'returns a new File object that you can write to' do
      temp = Tempfile.create('foo')
      temp.should be_an_instance_of(File)
      temp.write('hello world')
      temp.close
      File.read(temp.path).should == 'hello world'
    end
  end

  describe '#initialize' do
    before :each do
      @temp = nil
    end

    after :each do
      @temp.close! if @temp
    end

    it 'works with no arguments' do
      @temp = Tempfile.new
    end

    it 'works with a String basename argument' do
      @temp = Tempfile.new('basename')
      @temp.path.should.include?('basename')
    end

    it 'converts a basename argument with #to_str' do
      basename = mock('basename')
      basename.should_receive(:to_str).and_return('basename')
      @temp = Tempfile.new(basename)
      @temp.path.should.include?('basename')
    end

    it 'does not converts a basename argument with #to_path' do
      basename = mock('basename')
      basename.define_singleton_method(:to_path) { 'basename' }
      -> { Tempfile.new(basename) }.should raise_error(ArgumentError, /unexpected prefix: /)
    end
  end

  describe '#path' do
    it 'returns nil if the file is unlinked' do
      temp = Tempfile.new('foo')
      temp.unlink
      temp.path.should be_nil
    end
  end

  describe '#size' do
    it 'returns the actual size even after unlinking the file' do
      temp = Tempfile.new('foo')
      temp.write('hello')
      temp.unlink
      temp.write(' world')
      temp.length.should == 'hello world'.length
    end

    it 'raises ENOENT if the file is closed and unlinked' do
      temp = Tempfile.new('foo')
      temp.write('hello')
      temp.unlink
      temp.close
      -> { temp.length }.should raise_error(Errno::ENOENT, /No such file or directory/)
    end
  end
end
