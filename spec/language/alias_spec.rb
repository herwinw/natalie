require_relative '../spec_helper'

class AliasObject
  attr :foo
  attr_reader :bar
  attr_accessor :baz

  def prep; @foo = 3; @bar = 4; end
  def value; 5; end
  def false_value; 6; end
  def self.klass_method; 7; end
end

describe "The alias keyword" do
  before :each do
    @obj = AliasObject.new
    @meta = class << @obj;self;end
  end

  it "creates a new name for an existing method" do
    @meta.class_eval do
      alias __value value
    end
    @obj.__value.should == 5
  end

  it "works with a simple symbol on the left-hand side" do
    @meta.class_eval do
      alias :a value
    end
    @obj.a.should == 5
  end

  it "works with a single quoted symbol on the left-hand side" do
    @meta.class_eval do
      alias :'a' value
    end
    @obj.a.should == 5
  end

  it "works with a double quoted symbol on the left-hand side" do
    @meta.class_eval do
      alias :"a" value
    end
    @obj.a.should == 5
  end

  it "works with an interpolated symbol on the left-hand side" do
    @meta.class_eval do
      alias :"#{'a'}" value
    end
    @obj.a.should == 5
  end

  it "works with an interpolated symbol with non-literal embedded expression on the left-hand side" do
    NATFIXME 'eval with dynamic strings', exception: TypeError, message: 'eval() only works on static strings' do
      @meta.class_eval do
        eval %Q{
          alias :"#{'a' + ''.to_s}" value
        }
      end
      @obj.a.should == 5
    end
  end

  it "works with a simple symbol on the right-hand side" do
    @meta.class_eval do
      alias a :value
    end
    @obj.a.should == 5
  end

  it "works with a single quoted symbol on the right-hand side" do
    @meta.class_eval do
      alias a :'value'
    end
    @obj.a.should == 5
  end

  it "works with a double quoted symbol on the right-hand side" do
    @meta.class_eval do
      alias a :"value"
    end
    @obj.a.should == 5
  end

  it "works with an interpolated symbol on the right-hand side" do
    @meta.class_eval do
      alias a :"#{'value'}"
    end
    @obj.a.should == 5
  end

  it "works with an interpolated symbol with non-literal embedded expression on the right-hand side" do
    NATFIXME 'eval with dynamic strings', exception: TypeError, message: 'eval() only works on static strings' do
      @meta.class_eval do
        eval %Q{
          alias a :"#{'value' + ''.to_s}"
        }
      end
      @obj.a.should == 5
    end
  end

  it "adds the new method to the list of methods" do
    original_methods = @obj.methods
    @meta.class_eval do
      alias __value value
    end
    (@obj.methods - original_methods).map {|m| m.to_s }.should == ["__value"]
  end

  it "adds the new method to the list of public methods" do
    original_methods = @obj.public_methods
    @meta.class_eval do
      alias __value value
    end
    (@obj.public_methods - original_methods).map {|m| m.to_s }.should == ["__value"]
  end

  it "overwrites an existing method with the target name" do
    @meta.class_eval do
      alias false_value value
    end
    @obj.false_value.should == 5
  end

  it "is reversible" do
    @meta.class_eval do
      alias __value value
      alias value false_value
    end
    @obj.value.should == 6

    @meta.class_eval do
      alias value __value
    end
    @obj.value.should == 5
  end

  it "operates on the object's metaclass when used in instance_eval" do
    @obj.instance_eval do
      alias __value value
    end

    @obj.__value.should == 5
    -> { AliasObject.new.__value }.should raise_error(NoMethodError)
  end

  it "operates on the class/module metaclass when used in instance_eval" do
    AliasObject.instance_eval do
      alias __klass_method klass_method
    end

    AliasObject.__klass_method.should == 7
    -> { Object.__klass_method }.should raise_error(NoMethodError)
  end

  it "operates on the class/module metaclass when used in instance_exec" do
    AliasObject.instance_exec do
      alias __klass_method2 klass_method
    end

    AliasObject.__klass_method2.should == 7
    -> { Object.__klass_method2 }.should raise_error(NoMethodError)
  end

  it "operates on methods defined via attr, attr_reader, and attr_accessor" do
    @obj.prep
    @obj.instance_eval do
      alias afoo foo
      alias abar bar
      alias abaz baz
    end

    @obj.afoo.should == 3
    @obj.abar.should == 4
    @obj.baz = 5
    @obj.abaz.should == 5
  end

  it "operates on methods with splat arguments" do
    class AliasObject2;end
    AliasObject2.class_eval do
      def test(*args)
        4
      end
      def test_with_check(*args)
        test_without_check(*args)
      end
      alias test_without_check test
      alias test test_with_check
    end
    AliasObject2.new.test(1,2,3,4,5).should == 4
  end

  it "operates on methods with splat arguments on eigenclasses" do
    @meta.class_eval do
      def test(*args)
        4
      end
      def test_with_check(*args)
        test_without_check(*args)
      end
      alias test_without_check test
      alias test test_with_check
    end
    @obj.test(1,2,3,4,5).should == 4
  end

  it "operates on methods with splat arguments defined in a superclass" do
    alias_class = Class.new
    alias_class.class_eval do
      def test(*args)
        4
      end
      def test_with_check(*args)
        test_without_check(*args)
      end
    end
    sub = Class.new(alias_class) do
      alias test_without_check test
      alias test test_with_check
    end
    sub.new.test(1,2,3,4,5).should == 4
  end

  it "operates on methods with splat arguments defined in a superclass using text block for class eval" do
    subclass = Class.new(AliasObject)
    AliasObject.class_eval <<-code
      def test(*args)
        4
      end
      def test_with_check(*args)
        test_without_check(*args)
      end
      alias test_without_check test
      alias test test_with_check
    code
    subclass.new.test("testing").should == 4
  end

  it "is not allowed against Integer or String instances" do
    -> do
      1.instance_eval do
        alias :foo :to_s
      end
    end.should raise_error(TypeError)

    -> do
      :blah.instance_eval do
        alias :foo :to_s
      end
    end.should raise_error(TypeError)
  end

  it "on top level defines the alias on Object" do
    # because it defines on the default definee / current module
    ruby_exe("def foo; end; alias bla foo; print method(:bla).owner").should == "Object"
  end

  it "raises a NameError when passed a missing name" do
    -> { @meta.class_eval { alias undef_method not_exist } }.should raise_error(NameError) { |e|
      # a NameError and not a NoMethodError
      e.class.should == NameError
    }
  end

  it "defines the method on the aliased class when the original method is from a parent class" do
    NATFIXME 'defines the method on the aliased class when the original method is from a parent class', exception: SpecFailedException do
      parent = Class.new do
        def parent_method
        end
      end
      child = Class.new(parent) do
        alias parent_method_alias parent_method
      end

      child.instance_method(:parent_method_alias).owner.should == child
      child.instance_methods(false).should include(:parent_method_alias)
    end
  end
end

describe "The alias keyword" do
  it "can create a new global variable, synonym of the original" do
    code = '$a = 1; alias $b $a; p [$a, $b]; $b = 2; p [$a, $b]'
    ruby_exe(code).should == "[1, 1]\n[2, 2]\n"
  end

  it "can override an existing global variable and make them synonyms" do
    code = '$a = 1; $b = 2; alias $b $a; p [$a, $b]; $b = 3; p [$a, $b]'
    ruby_exe(code).should == "[1, 1]\n[3, 3]\n"
  end

  it "supports aliasing twice the same global variables" do
    code = '$a = 1; alias $b $a; alias $b $a; p [$a, $b]'
    ruby_exe(code).should == "[1, 1]\n"
  end
end
