require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "Enumerable#to_h" do
  it "converts empty enumerable to empty hash" do
    enum = EnumerableSpecs::EachDefiner.new
    enum.to_h.should == {}
  end

  it "converts yielded [key, value] pairs to a hash" do
    enum = EnumerableSpecs::EachDefiner.new([:a, 1], [:b, 2])
    enum.to_h.should == { a: 1, b: 2 }
  end

  it "uses the last value of a duplicated key" do
    enum = EnumerableSpecs::EachDefiner.new([:a, 1], [:b, 2], [:a, 3])
    enum.to_h.should == { a: 3, b: 2 }
  end

  it "calls #to_ary on contents" do
    pair = mock('to_ary')
    pair.should_receive(:to_ary).and_return([:b, 2])
    enum = EnumerableSpecs::EachDefiner.new([:a, 1], pair)
    enum.to_h.should == { a: 1, b: 2 }
  end

  it "forwards arguments to #each" do
    enum = Object.new
    def enum.each(*args)
      yield(*args)
      yield([:b, 2])
    end
    enum.extend Enumerable
    enum.to_h(:a, 1).should == { a: 1, b: 2 }
  end

  it "raises TypeError if an element is not an array" do
    enum = EnumerableSpecs::EachDefiner.new(:x)
    -> { enum.to_h }.should raise_error(TypeError)
  end

  it "raises ArgumentError if an element is not a [key, value] pair" do
    enum = EnumerableSpecs::EachDefiner.new([:x])
    -> { enum.to_h }.should raise_error(ArgumentError)
  end

  context "with block" do
    before do
      @enum = EnumerableSpecs::EachDefiner.new(:a, :b)
    end

    it "converts [key, value] pairs returned by the block to a hash" do
      @enum.to_h { |k| [k, k.to_s] }.should == { a: 'a', b: 'b' }
    end

    it "passes to a block each element as a single argument" do
      enum_of_arrays = EnumerableSpecs::EachDefiner.new([:a, 1], [:b, 2])

      ScratchPad.record []
      enum_of_arrays.to_h { |*args| ScratchPad << args; [args[0], args[1]] }
      ScratchPad.recorded.sort.should == [[[:a, 1]], [[:b, 2]]]
    end

    it "raises ArgumentError if block returns longer or shorter array" do
      -> do
        @enum.to_h { |k| [k, k.to_s, 1] }
      end.should raise_error(ArgumentError, /element has wrong array length/)

      -> do
        @enum.to_h { |k| [k] }
      end.should raise_error(ArgumentError, /element has wrong array length/)
    end

    it "raises TypeError if block returns something other than Array" do
      -> do
        @enum.to_h { |k| "not-array" }
      end.should raise_error(TypeError, /wrong element type String/)
    end

    it "coerces returned pair to Array with #to_ary" do
      x = mock('x')
      x.stub!(:to_ary).and_return([:b, 'b'])

      @enum.to_h { |k| x }.should == { :b => 'b' }
    end

    it "does not coerce returned pair to Array with #to_a" do
      x = mock('x')
      x.stub!(:to_a).and_return([:b, 'b'])

      -> do
        @enum.to_h { |k| x }
      end.should raise_error(TypeError, /wrong element type MockObject/)
    end
  end
end
