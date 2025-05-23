require_relative '../../../spec_helper'
require_relative '../fixtures/classes'

# Describes Numeric#step shared specs between different argument styles.
# To be able to do it, the @step ivar must contain a Proc that transforms
# the step call arguments passed as positional arguments to the style of
# arguments pretended to test.
describe :numeric_step, :shared => true do
  before :each do
    ScratchPad.record []
    @prc = -> x { ScratchPad << x }
  end

  it "defaults to step = 1" do
    @step.call(1, 5, &@prc)
    ScratchPad.recorded.should eql [1, 2, 3, 4, 5]
  end

  it "defaults to an infinite limit with a step size of 1 for Integers" do
    1.step.first(5).should == [1, 2, 3, 4, 5]
  end

  it "defaults to an infinite limit with a step size of 1.0 for Floats" do
    1.0.step.first(5).should == [1.0, 2.0, 3.0, 4.0, 5.0]
  end

  describe "when self, stop and step are Integers" do
    it "yields only Integers" do
      @step.call(1, 5, 1) { |x| x.should be_an_instance_of(Integer) }
    end

    describe "with a positive step" do
      it "yields while increasing self by step until stop is reached" do
        @step.call(1, 5, 1, &@prc)
        ScratchPad.recorded.should eql [1, 2, 3, 4, 5]
      end

      it "yields once when self equals stop" do
        @step.call(1, 1, 1, &@prc)
        ScratchPad.recorded.should eql [1]
      end

      it "does not yield when self is greater than stop" do
        @step.call(2, 1, 1, &@prc)
        ScratchPad.recorded.should eql []
      end
    end

    describe "with a negative step" do
      it "yields while decreasing self by step until stop is reached" do
        @step.call(5, 1, -1, &@prc)
        ScratchPad.recorded.should eql [5, 4, 3, 2, 1]
      end

      it "yields once when self equals stop" do
        @step.call(5, 5, -1, &@prc)
        ScratchPad.recorded.should eql [5]
      end

      it "does not yield when self is less than stop" do
        @step.call(1, 5, -1, &@prc)
        ScratchPad.recorded.should == []
      end
    end
  end

  describe "when at least one of self, stop or step is a Float" do
    it "yields Floats even if only self is a Float" do
      @step.call(1.5, 5, 1) { |x| x.should be_an_instance_of(Float) }
    end

    it "yields Floats even if only stop is a Float" do
      @step.call(1, 5.0, 1) { |x| x.should be_an_instance_of(Float) }
    end

    it "yields Floats even if only step is a Float" do
      @step.call(1, 5, 1.0) { |x| x.should be_an_instance_of(Float) }
    end

    describe "with a positive step" do
      it "yields while increasing self by step while < stop" do
        @step.call(1.5, 5, 1, &@prc)
        ScratchPad.recorded.should eql [1.5, 2.5, 3.5, 4.5]
      end

      it "yields once when self equals stop" do
        @step.call(1.5, 1.5, 1, &@prc)
        ScratchPad.recorded.should eql [1.5]
      end

      it "does not yield when self is greater than stop" do
        @step.call(2.5, 1.5, 1, &@prc)
        ScratchPad.recorded.should == []
      end

      it "is careful about not yielding a value greater than limit" do
        # As 9*1.3+1.0 == 12.700000000000001 > 12.7, we test:
        @step.call(1.0, 12.7, 1.3, &@prc)
        ScratchPad.recorded.should eql [1.0, 2.3, 3.6, 4.9, 6.2, 7.5, 8.8, 10.1, 11.4, 12.7]
      end
    end

    describe "with a negative step" do
      it "yields while decreasing self by step while self > stop" do
        @step.call(5, 1.5, -1, &@prc)
        ScratchPad.recorded.should eql [5.0, 4.0, 3.0, 2.0]
      end

      it "yields once when self equals stop" do
        @step.call(1.5, 1.5, -1, &@prc)
        ScratchPad.recorded.should eql [1.5]
      end

      it "does not yield when self is less than stop" do
        @step.call(1, 5, -1.5, &@prc)
        ScratchPad.recorded.should == []
      end

      it "is careful about not yielding a value smaller than limit" do
        # As -9*1.3-1.0 == -12.700000000000001 < -12.7, we test:
        @step.call(-1.0, -12.7, -1.3, &@prc)
        ScratchPad.recorded.should eql [-1.0, -2.3, -3.6, -4.9, -6.2, -7.5, -8.8, -10.1, -11.4, -12.7]
      end
    end

    describe "with a positive Infinity step" do
      it "yields once if self < stop" do
        @step.call(42, 100, infinity_value, &@prc)
        ScratchPad.recorded.should eql [42.0]
      end

      it "yields once when stop is Infinity" do
        @step.call(42, infinity_value, infinity_value, &@prc)
        ScratchPad.recorded.should eql [42.0]
      end

      it "yields once when self equals stop" do
        @step.call(42, 42, infinity_value, &@prc)
        ScratchPad.recorded.should eql [42.0]
      end

      it "yields once when self and stop are Infinity" do
        # @step.call(infinity_value, infinity_value, infinity_value, &@prc)
        @step.call(infinity_value, infinity_value, infinity_value, &@prc)
        ScratchPad.recorded.should == [infinity_value]
      end

      it "does not yield when self > stop" do
        @step.call(100, 42, infinity_value, &@prc)
        ScratchPad.recorded.should == []
      end

      it "does not yield when stop is -Infinity" do
        @step.call(42, -infinity_value, infinity_value, &@prc)
        ScratchPad.recorded.should == []
      end
    end

    describe "with a negative Infinity step" do
      it "yields once if self > stop" do
        @step.call(42, 6, -infinity_value, &@prc)
        ScratchPad.recorded.should eql [42.0]
      end

      it "yields once if stop is -Infinity" do
        @step.call(42, -infinity_value, -infinity_value, &@prc)
        ScratchPad.recorded.should eql [42.0]
      end

      it "yields once when self equals stop" do
        @step.call(42, 42, -infinity_value, &@prc)
        ScratchPad.recorded.should eql [42.0]
      end

      it "yields once when self and stop are Infinity" do
        @step.call(infinity_value, infinity_value, -infinity_value, &@prc)
        ScratchPad.recorded.should == [infinity_value]
      end

      it "does not yield when self > stop" do
        @step.call(42, 100, -infinity_value, &@prc)
        ScratchPad.recorded.should == []
      end

      it "does not yield when stop is Infinity" do
        @step.call(42, infinity_value, -infinity_value, &@prc)
        ScratchPad.recorded.should == []
      end
    end

    describe "with a Infinity stop and a positive step" do
      it "does not yield when self is infinity" do
        @step.call(infinity_value, infinity_value, 1, &@prc)
        ScratchPad.recorded.should == []
      end
    end

    describe "with a Infinity stop and a negative step" do
      it "does not yield when self is negative infinity" do
        @step.call(-infinity_value, infinity_value, -1, &@prc)
        ScratchPad.recorded.should == []
      end

      it "does not yield when self is positive infinity" do
        @step.call(infinity_value, infinity_value, -1, &@prc)
        ScratchPad.recorded.should == []
      end
    end

    describe "with a negative Infinity stop and a positive step" do
      it "does not yield when self is negative infinity" do
        @step.call(-infinity_value, -infinity_value, 1, &@prc)
        ScratchPad.recorded.should == []
      end
    end

    describe "with a negative Infinity stop and a negative step" do
      it "does not yield when self is negative infinity" do
        @step.call(-infinity_value, -infinity_value, -1, &@prc)
        ScratchPad.recorded.should == []
      end
    end

  end

  describe "when step is a String" do
    describe "with self and stop as Integers" do
      it "raises an ArgumentError when step is a numeric representation" do
        -> { @step.call(1, 5, "1") {} }.should raise_error(ArgumentError)
        -> { @step.call(1, 5, "0.1") {} }.should raise_error(ArgumentError)
        -> { @step.call(1, 5, "1/3") {} }.should raise_error(ArgumentError)
      end
      it "raises an ArgumentError with step as an alphanumeric string" do
        -> { @step.call(1, 5, "foo") {} }.should raise_error(ArgumentError)
      end
    end

    describe "with self and stop as Floats" do
      it "raises an ArgumentError when step is a numeric representation" do
        -> { @step.call(1.1, 5.1, "1") {} }.should raise_error(ArgumentError)
        -> { @step.call(1.1, 5.1, "0.1") {} }.should raise_error(ArgumentError)
        -> { @step.call(1.1, 5.1, "1/3") {} }.should raise_error(ArgumentError)
      end
      it "raises an ArgumentError with step as an alphanumeric string" do
        -> { @step.call(1.1, 5.1, "foo") {} }.should raise_error(ArgumentError)
      end
    end
  end

  it "does not rescue ArgumentError exceptions" do
    -> { @step.call(1, 2) { raise ArgumentError, "" }}.should raise_error(ArgumentError)
  end

  it "does not rescue TypeError exceptions" do
    -> { @step.call(1, 2) { raise TypeError, "" } }.should raise_error(TypeError)
  end

  describe "when no block is given" do
    step_enum_class = Enumerator::ArithmeticSequence

    it "returns an #{step_enum_class} when not passed a block and self > stop" do
      @step.call(1, 0, 2).should be_an_instance_of(step_enum_class)
    end

    it "returns an #{step_enum_class} when not passed a block and self < stop" do
      @step.call(1, 2, 3).should be_an_instance_of(step_enum_class)
    end

    it "returns an #{step_enum_class} that uses the given step" do
      @step.call(0, 5, 2).to_a.should eql [0, 2, 4]
    end

    describe "when step is a String" do
      describe "with self and stop as Integers" do
        it "returns an Enumerator" do
          NATFIXME 'Fix step argument for Ruby 3.4, and this will probably no longer be numeric', exception: SpecFailedException do
            @step.call(1, 5, "foo").should be_an_instance_of(Enumerator)
          end
        end
      end

      describe "with self and stop as Floats" do
        it "returns an Enumerator" do
          NATFIXME 'Fix step argument for Ruby 3.4, and this will probably no longer be numeric', exception: SpecFailedException do
            @step.call(1.1, 5.1, "foo").should be_an_instance_of(Enumerator)
          end
        end
      end
    end

    describe "returned Enumerator" do
      describe "size" do
        describe "when step is a String" do
          describe "with self and stop as Integers" do
            it "raises an ArgumentError when step is a numeric representation" do
              -> { @step.call(1, 5, "1").size }.should raise_error(ArgumentError)
              -> { @step.call(1, 5, "0.1").size }.should raise_error(ArgumentError)
              -> { @step.call(1, 5, "1/3").size }.should raise_error(ArgumentError)
            end
            it "raises an ArgumentError with step as an alphanumeric string" do
              -> { @step.call(1, 5, "foo").size }.should raise_error(ArgumentError)
            end
          end

          describe "with self and stop as Floats" do
            it "raises an ArgumentError when step is a numeric representation" do
              -> { @step.call(1.1, 5.1, "1").size }.should raise_error(ArgumentError)
              -> { @step.call(1.1, 5.1, "0.1").size }.should raise_error(ArgumentError)
              -> { @step.call(1.1, 5.1, "1/3").size }.should raise_error(ArgumentError)
            end
            it "raises an ArgumentError with step as an alphanumeric string" do
              -> { @step.call(1.1, 5.1, "foo").size }.should raise_error(ArgumentError)
            end
          end
        end

        describe "when self, stop and step are Integers and step is positive" do
          it "returns the difference between self and stop divided by the number of steps" do
            @step.call(5, 10, 11).size.should == 1
            @step.call(5, 10, 6).size.should == 1
            @step.call(5, 10, 5).size.should == 2
            @step.call(5, 10, 4).size.should == 2
            @step.call(5, 10, 2).size.should == 3
            @step.call(5, 10, 1).size.should == 6
            @step.call(5, 10).size.should == 6
            @step.call(10, 10, 1).size.should == 1
          end

          it "returns 0 if value > limit" do
            @step.call(11, 10, 1).size.should == 0
          end
        end

        describe "when self, stop and step are Integers and step is negative" do
          it "returns the difference between self and stop divided by the number of steps" do
            @step.call(10, 5, -11).size.should == 1
            @step.call(10, 5, -6).size.should == 1
            @step.call(10, 5, -5).size.should == 2
            @step.call(10, 5, -4).size.should == 2
            @step.call(10, 5, -2).size.should == 3
            @step.call(10, 5, -1).size.should == 6
            @step.call(10, 10, -1).size.should == 1
          end

          it "returns 0 if value < limit" do
            @step.call(10, 11, -1).size.should == 0
          end
        end

        describe "when self, stop or step is a Float" do
          describe "and step is positive" do
            it "returns the difference between self and stop divided by the number of steps" do
              @step.call(5, 10, 11.0).size.should == 1
              @step.call(5, 10, 6.0).size.should == 1
              @step.call(5, 10, 5.0).size.should == 2
              @step.call(5, 10, 4.0).size.should == 2
              @step.call(5, 10, 2.0).size.should == 3
              @step.call(5, 10, 0.5).size.should == 11
              @step.call(5, 10, 1.0).size.should == 6
              @step.call(5, 10.5).size.should == 6
              @step.call(10, 10, 1.0).size.should == 1
            end

            it "returns 0 if value > limit" do
              @step.call(10, 5.5).size.should == 0
              @step.call(11, 10, 1.0).size.should == 0
              @step.call(11, 10, 1.5).size.should == 0
              @step.call(10, 5, infinity_value).size.should == 0
            end

            it "returns 1 if step is infinity_value" do
              @step.call(5, 10, infinity_value).size.should == 1
            end
          end

          describe "and step is negative" do
            it "returns the difference between self and stop divided by the number of steps" do
              @step.call(10, 5, -11.0).size.should == 1
              @step.call(10, 5, -6.0).size.should == 1
              @step.call(10, 5, -5.0).size.should == 2
              @step.call(10, 5, -4.0).size.should == 2
              @step.call(10, 5, -2.0).size.should == 3
              @step.call(10, 5, -0.5).size.should == 11
              @step.call(10, 5, -1.0).size.should == 6
              @step.call(10, 10, -1.0).size.should == 1
            end

            it "returns 0 if value < limit" do
              @step.call(10, 11, -1.0).size.should == 0
              @step.call(10, 11, -1.5).size.should == 0
              @step.call(5, 10, -infinity_value).size.should == 0
            end

            it "returns 1 if step is infinity_value" do
              @step.call(10, 5, -infinity_value).size.should == 1
            end
          end
        end

        describe "when stop is not passed" do
          it "returns infinity_value" do
            @step.call(1).size.should == infinity_value
          end
        end

        describe "when stop is nil" do
          it "returns infinity_value" do
            @step.call(1, nil, 5).size.should == infinity_value
          end
        end
      end
    end
  end
end
