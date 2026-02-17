require_relative '../spec_helper'

def m_private = :private

class Object
  def m_private_2 = :private_2
end

private :m_private_2

public

def m_public = :public

private

class Object
  private

  def m_public_2 = :public_2
end

public :m_public_2

def m_private_3 = :private_3

describe 'top-level method visibility' do
  it 'defaults top-level method visibility to private' do
    -> { Object.new.m_private }.should raise_error(NoMethodError, /private/)
  end

  it 'sets Object method visibility to private from the top level' do
    -> { Object.new.m_private_2 }.should raise_error(NoMethodError, /private/)
  end

  it 'sets top-level method visibility' do
    Object.new.m_public.should == :public
  end

  it 'sets Object method visibility to public from the top level' do
    Object.new.m_public_2.should == :public_2
  end

  it 'persists top-level visibility' do
    -> { Object.new.m_private_3 }.should raise_error(NoMethodError, /private/)
  end
end
