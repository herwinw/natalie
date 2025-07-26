require_relative '../spec_helper'

module M1
end

module M2
  include M1
end

class C1
  include M1
end

module M3
  include M2
  module M3A
    def m3a
      'm3a'
    end
  end
  class A
    class << self
      include M3A
    end
  end
end

module M4
  include M1
  include M1
end

module M5
  prepend M1
  prepend M1
end

class C2 < C1
end

describe 'Module' do
  describe '.include?' do
    it 'returns true if the module includes the given module' do
      M2.include?(M2).should == false
      M2.include?(M1).should == true
      M1.include?(M2).should == false
      M3.include?(M1).should == true
      C1.include?(M1).should == true
      C1.include?(M2).should == false
      C2.include?(M1).should == true
      -> { C1.include?(nil) }.should raise_error(TypeError)
    end
  end

  describe 'include' do
    it 'works on the singleton class' do
      M3::A.m3a.should == 'm3a'
    end

    it 'does not include the same module more than once' do
      M4.ancestors.count(M1).should == 1
    end
  end

  describe 'prepend' do
    it 'does not prepend the same module more than once' do
      M5.ancestors.count(M1).should == 1
    end
  end

  describe '#const_get' do
    it 'returns a constant by name' do
      Object.const_get(:M3).should == M3
      M3.const_get('A').should == M3::A
    end

    it 'raises a NameError if no constant is defined' do
      -> { M1.const_get(:NameNotDefined) }.should raise_error(NameError)
    end
  end

  describe '#name' do
    it 'returns the fully-qualified name' do
      M3::M3A.name.should == 'M3::M3A'
    end
  end

  describe '#constants' do
    it 'returns an array of constant names' do
      M3.constants.sort.should == %i[A M3A]
    end
  end

  describe '#private_methods' do
    mod =
      Module.new do
        private

        def m_mod = :m
      end
    klass =
      Class.new do
        include mod

        private

        def m_klass = :k
      end
    klass.new.private_methods.grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.private_methods(true).grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.private_methods(1).grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.private_methods(false).grep(/^m_/).sort.should == %i[m_klass]
    klass.new.private_methods(nil).grep(/^m_/).sort.should == %i[m_klass]
  end

  describe '#protected_methods' do
    mod =
      Module.new do
        protected

        def m_mod = :m
      end
    klass =
      Class.new do
        include mod

        protected

        def m_klass = :k
      end
    klass.new.protected_methods.grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.protected_methods(true).grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.protected_methods(1).grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.protected_methods(false).grep(/^m_/).sort.should == %i[m_klass]
    klass.new.protected_methods(nil).grep(/^m_/).sort.should == %i[m_klass]
  end

  describe '#public_methods' do
    mod = Module.new { def m_mod = :m }
    klass =
      Class.new do
        include mod
        def m_klass = :k
      end
    klass.new.public_methods.grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.public_methods(true).grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.public_methods(1).grep(/^m_/).sort.should == %i[m_klass m_mod]
    klass.new.public_methods(false).grep(/^m_/).sort.should == %i[m_klass]
    klass.new.public_methods(nil).grep(/^m_/).sort.should == %i[m_klass]
  end
end
