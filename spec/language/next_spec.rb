require_relative '../spec_helper'
require_relative 'fixtures/next'

describe "The next statement from within the block" do
  before :each do
    ScratchPad.record []
  end

  it "ends block execution" do
    a = []
    -> {
      a << 1
      next
      a << 2
    }.call
    a.should == [1]
  end

  it "causes block to return nil if invoked without arguments" do
    -> { 123; next; 456 }.call.should == nil
  end

  it "causes block to return nil if invoked with an empty expression" do
    -> { next (); 456 }.call.should be_nil
  end

  it "returns the argument passed" do
    -> { 123; next 234; 345 }.call.should == 234
  end

  it "returns to the invoking method" do
    NextSpecs.yielding_method(nil) { next }.should == :method_return_value
  end

  it "returns to the invoking method, with the specified value" do
    NextSpecs.yielding_method(nil) {
      next nil;
      fail("next didn't end the block execution")
    }.should == :method_return_value

    NextSpecs.yielding_method(1) {
      next 1
      fail("next didn't end the block execution")
    }.should == :method_return_value

    NextSpecs.yielding_method([1, 2, 3]) {
      next 1, 2, 3
      fail("next didn't end the block execution")
    }.should == :method_return_value
  end

  it "returns to the currently yielding method in case of chained calls" do
    class ChainedNextTest
      def self.meth_with_yield(&b)
        yield.should == :next_return_value
        :method_return_value
      end
      def self.invoking_method(&b)
        meth_with_yield(&b)
      end
      def self.enclosing_method
        invoking_method do
          next :next_return_value
          :wrong_return_value
        end
      end
    end

    ChainedNextTest.enclosing_method.should == :method_return_value
  end

  it "causes ensure blocks to run" do
    [1].each do |i|
      begin
        ScratchPad << :begin
        next
      ensure
        ScratchPad << :ensure
      end
    end

    NATFIXME 'it causes ensure blocks to run', exception: SpecFailedException do
      ScratchPad.recorded.should == [:begin, :ensure]
    end
  end

  it "skips following code outside an exception block" do
    3.times do |i|
      begin
        ScratchPad << :begin
        next if i == 0
        break if i == 2
        ScratchPad << :begin_end
      ensure
        ScratchPad << :ensure
      end

      ScratchPad << :after
    end

    NATFIXME 'it skips following code outside an exception block', exception: SpecFailedException do
      ScratchPad.recorded.should == [
        :begin, :ensure, :begin, :begin_end, :ensure, :after, :begin, :ensure]
    end
  end

  it "passes the value returned by a method with omitted parenthesis and passed block" do
    obj = NextSpecs::Block.new
    -> { next obj.method :value do |x| x end }.call.should == :value
  end
end

describe "The next statement" do
  describe "in a method" do
    it "is invalid and raises a SyntaxError" do
      -> {
        eval("def m; next; end")
      }.should raise_error(SyntaxError)
    end
  end
end

describe "The next statement" do
  before :each do
    ScratchPad.record []
  end

  describe "in a while loop" do
    describe "when not passed an argument" do
      it "causes ensure blocks to run" do
        NextSpecs.while_next(false)

        NATFIXME 'it causes ensure blocks to run', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end

      it "causes ensure blocks to run when nested in an block" do
        NextSpecs.while_within_iter(false)

        NATFIXME 'it causes ensure blocks to run when nested in an block', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end
    end

    describe "when passed an argument" do
      it "causes ensure blocks to run" do
        NextSpecs.while_next(true)

        NATFIXME 'it causes ensure blocks to run', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end

      it "causes ensure blocks to run when nested in an block" do
        NextSpecs.while_within_iter(true)

        NATFIXME 'it causes ensure blocks to run when nested in an block', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end
    end

    it "causes nested ensure blocks to run" do
      x = true
      while x
        begin
          ScratchPad << :outer_begin
          x = false
          begin
            ScratchPad << :inner_begin
            next
          ensure
            ScratchPad << :inner_ensure
          end
        ensure
          ScratchPad << :outer_ensure
        end
      end

      NATFIXME 'it causes nested ensure blocks to run', exception: SpecFailedException do
        ScratchPad.recorded.should == [:outer_begin, :inner_begin, :inner_ensure, :outer_ensure]
      end
    end

    it "causes ensure blocks to run when mixed with break" do
      x = 1
      while true
        begin
          ScratchPad << :begin
          break if x > 1
          x += 1
          next
        ensure
          ScratchPad << :ensure
        end
      end

      NATFIXME 'it causes ensure blocks to run when mixed with break', exception: SpecFailedException do
        ScratchPad.recorded.should == [:begin, :ensure, :begin, :ensure]
      end
    end
  end

  describe "in an until loop" do
    describe "when not passed an argument" do
      it "causes ensure blocks to run" do
        NextSpecs.until_next(false)

        NATFIXME 'it causes ensure blocks to run', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end

      it "causes ensure blocks to run when nested in an block" do
        NextSpecs.until_within_iter(false)

        NATFIXME 'it causes ensure blocks to run when nested in an block', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end
    end

    describe "when passed an argument" do
      it "causes ensure blocks to run" do
        NextSpecs.until_next(true)

        NATFIXME 'it causes ensure blocks to run', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end

      it "causes ensure blocks to run when nested in an block" do
        NextSpecs.until_within_iter(true)

        NATFIXME 'it causes ensure blocks to run when nested in an block', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end
    end

    it "causes nested ensure blocks to run" do
      x = false
      until x
        begin
          ScratchPad << :outer_begin
          x = true
          begin
            ScratchPad << :inner_begin
            next
          ensure
            ScratchPad << :inner_ensure
          end
        ensure
          ScratchPad << :outer_ensure
        end
      end

      NATFIXME 'it causes nested ensure blocks to run', exception: SpecFailedException do
        ScratchPad.recorded.should == [:outer_begin, :inner_begin, :inner_ensure, :outer_ensure]
      end
    end

    it "causes ensure blocks to run when mixed with break" do
      x = 1
      until false
        begin
          ScratchPad << :begin
          break if x > 1
          x += 1
          next
        ensure
          ScratchPad << :ensure
        end
      end

      NATFIXME 'it causes ensure blocks to run when mixed with break', exception: SpecFailedException do
        ScratchPad.recorded.should == [:begin, :ensure, :begin, :ensure]
      end
    end
  end

  describe "in a loop" do
    describe "when not passed an argument" do
      it "causes ensure blocks to run" do
        NextSpecs.loop_next(false)

        NATFIXME 'it causes ensure blocks to run', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end

      it "causes ensure blocks to run when nested in an block" do
        NextSpecs.loop_within_iter(false)

        NATFIXME 'it causes ensure blocks to run when nested in an block', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end
    end

    describe "when passed an argument" do
      it "causes ensure blocks to run" do
        NextSpecs.loop_next(true)

        NATFIXME 'it causes ensure blocks to run', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end

      it "causes ensure blocks to run when nested in an block" do
        NextSpecs.loop_within_iter(true)

        NATFIXME 'it causes ensure blocks to run when nested in an block', exception: SpecFailedException do
          ScratchPad.recorded.should == [:begin, :ensure]
        end
      end
    end

    it "causes nested ensure blocks to run" do
      x = 1
      loop do
        break if x == 2

        begin
          ScratchPad << :outer_begin
          begin
            ScratchPad << :inner_begin
            x += 1
            next
          ensure
            ScratchPad << :inner_ensure
          end
        ensure
          ScratchPad << :outer_ensure
        end
      end

      NATFIXME 'it causes nested ensure blocks to run', exception: SpecFailedException do
        ScratchPad.recorded.should == [:outer_begin, :inner_begin, :inner_ensure, :outer_ensure]
      end
    end

    it "causes ensure blocks to run when mixed with break" do
      x = 1
      loop do
        begin
          ScratchPad << :begin
          break if x > 1
          x += 1
          next
        ensure
          ScratchPad << :ensure
        end
      end

      NATFIXME 'it causes ensure blocks to run when mixed with break', exception: SpecFailedException do
        ScratchPad.recorded.should == [:begin, :ensure, :begin, :ensure]
      end
    end
  end
end

describe "Assignment via next" do
  it "assigns objects" do
    def r(val); a = yield(); val.should == a; end
    r(nil){next}
    r(nil){next nil}
    r(1){next 1}
    r([]){next []}
    r([1]){next [1]}
    r([nil]){next [nil]}
    r([[]]){next [[]]}
    r([]){next [*[]]}
    r([1]){next [*[1]]}
    r([1,2]){next [*[1,2]]}
  end

  it "assigns splatted objects" do
    def r(val); a = yield(); val.should == a; end
    NATFIXME 'it assigns splatted objects', exception: SpecFailedException do
      r([]){next *nil}
      r([1]){next *1}
      r([]){next *[]}
      r([1]){next *[1]}
      r([nil]){next *[nil]}
      r([[]]){next *[[]]}
      r([]){next *[*[]]}
      r([1]){next *[*[1]]}
      r([1,2]){next *[*[1,2]]}
    end
  end

  it "assigns objects to a splatted reference" do
    def r(val); *a = yield(); val.should == a; end
    r([nil]){next}
    r([nil]){next nil}
    r([1]){next 1}
    r([]){next []}
    r([1]){next [1]}
    r([nil]){next [nil]}
    r([[]]){next [[]]}
    r([1,2]){next [1,2]}
    r([]){next [*[]]}
    r([1]){next [*[1]]}
    r([1,2]){next [*[1,2]]}
  end

  it "assigns splatted objects to a splatted reference via a splatted yield" do
    def r(val); *a = *yield(); val.should == a; end
    r([]){next *nil}
    r([1]){next *1}
    r([]){next *[]}
    r([1]){next *[1]}
    r([nil]){next *[nil]}
    r([[]]){next *[[]]}
    r([1,2]){next *[1,2]}
    r([]){next *[*[]]}
    r([1]){next *[*[1]]}
    r([1,2]){next *[*[1,2]]}
  end

  it "assigns objects to multiple variables" do
    def r(val); a,b,*c = yield(); val.should == [a,b,c]; end
    r([nil,nil,[]]){next}
    r([nil,nil,[]]){next nil}
    r([1,nil,[]]){next 1}
    r([nil,nil,[]]){next []}
    r([1,nil,[]]){next [1]}
    r([nil,nil,[]]){next [nil]}
    r([[],nil,[]]){next [[]]}
    r([1,2,[]]){next [1,2]}
    r([nil,nil,[]]){next [*[]]}
    r([1,nil,[]]){next [*[1]]}
    r([1,2,[]]){next [*[1,2]]}
  end

  it "assigns splatted objects to multiple variables" do
    def r(val); a,b,*c = *yield(); val.should == [a,b,c]; end
    r([nil,nil,[]]){next *nil}
    r([1,nil,[]]){next *1}
    r([nil,nil,[]]){next *[]}
    r([1,nil,[]]){next *[1]}
    r([nil,nil,[]]){next *[nil]}
    r([[],nil,[]]){next *[[]]}
    r([1,2,[]]){next *[1,2]}
    r([nil,nil,[]]){next *[*[]]}
    r([1,nil,[]]){next *[*[1]]}
    r([1,2,[]]){next *[*[1,2]]}
  end
end
