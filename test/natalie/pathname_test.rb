require_relative '../spec_helper'
require 'pathname'

describe 'Pathname.pwd' do
  it 'returns the current working directory' do
    Pathname.pwd.should == Pathname.getwd
    NATFIXME 'Pathname#eql? with a String argument', exception: SpecFailedException do
      Pathname.pwd.should.eql?(Dir.getwd)
    end
  end
end

describe 'Pathname.getwd' do
  it 'is an alias for Pathname.pwd' do
    Pathname.getwd.should == Pathname.pwd
  end
end
