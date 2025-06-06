require_relative '../../spec_helper'
require_relative 'fixtures/common'

describe "BasicObject" do
  it "raises NoMethodError for nonexistent methods after #method_missing is removed" do
    script = fixture __FILE__, "remove_method_missing.rb"
    ruby_exe(script).chomp.should == "NoMethodError"
  end

  it "raises NameError when referencing built-in constants" do
    NATFIXME 'raises NameError when referencing built-in constants', exception: SpecFailedException do
      -> { class BasicObjectSpecs::BOSubclass; Kernel; end }.should raise_error(NameError)
    end
  end

  it "does not define built-in constants (according to const_defined?)" do
    NATFIXME 'does not define built-in constants (according to const_defined?)', exception: SpecFailedException do
      BasicObject.const_defined?(:Kernel).should be_false
    end
  end

  it "does not define built-in constants (according to defined?)" do
    NATFIXME 'does not define built-in constants (according to defined?)', exception: SpecFailedException do
      BasicObjectSpecs::BOSubclass.kernel_defined?.should be_nil
    end
  end

  it "is included in Object's list of constants" do
    Object.constants(false).should include(:BasicObject)
  end

  it "includes itself in its list of constants" do
    NATFIXME 'includes itself in its list of constants', exception: SpecFailedException do
      BasicObject.constants(false).should include(:BasicObject)
    end
  end
end

describe "BasicObject metaclass" do
  before :each do
    @meta = class << BasicObject; self; end
  end

  it "is an instance of Class" do
    @meta.should be_an_instance_of(Class)
  end

  it "has Class as superclass" do
    @meta.superclass.should equal(Class)
  end

  it "contains methods for the BasicObject class" do
    @meta.class_eval do
      def rubyspec_test_method() :test end
    end

    BasicObject.rubyspec_test_method.should == :test
  end
end

describe "BasicObject instance metaclass" do
  before :each do
    @object = BasicObject.new
    @meta = class << @object; self; end
  end

  it "is an instance of Class" do
    NATFIXME 'it is an instance of Class', exception: SpecFailedException do
      @meta.should be_an_instance_of(Class)
    end
  end

  it "has BasicObject as superclass" do
    @meta.superclass.should equal(BasicObject)
  end

  it "contains methods defined for the BasicObject instance" do
    @meta.class_eval do
      def test_method() :test end
    end

    @object.test_method.should == :test
  end
end

describe "BasicObject subclass" do
  it "contains Kernel methods when including Kernel" do
    obj = BasicObjectSpecs::BOSubclass.new

    obj.instance_variable_set(:@test, :value)
    obj.instance_variable_get(:@test).should == :value

    obj.respond_to?(:hash).should == true
  end

  describe "BasicObject references" do
    it "can refer to BasicObject from within itself" do
      NATFIXME 'uninitialized constant BasicObject::BasicObject (NameError)', exception: SpecFailedException do
        -> { BasicObject::BasicObject }.should_not raise_error
      end
    end
  end
end
