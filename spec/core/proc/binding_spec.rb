require_relative '../../spec_helper'

describe "Proc#binding" do
  it "returns a Binding instance" do
    [Proc.new{}, -> {}, proc {}].each { |p|
      p.binding.should be_kind_of(Binding)
    }
  end

  it "returns the binding associated with self" do
    obj = mock('binding')
    def obj.test_binding(some, params)
      -> {}
    end

    lambdas_binding = obj.test_binding(1, 2).binding

    NATFIXME 'binding passed to eval() will be ignored.', exception: NoMethodError, message: "undefined method `some' for main" do
      eval("some", lambdas_binding).should == 1
      eval("params", lambdas_binding).should == 2
    end
  end
end
