require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "Array#sample" do
  it "samples evenly" do
    NATFIXME 'it samples evenly', exception: SpecFailedException do
      ArraySpecs.measure_sample_fairness(4, 1, 400)
      ArraySpecs.measure_sample_fairness(4, 2, 400)
      ArraySpecs.measure_sample_fairness(4, 3, 400)
      ArraySpecs.measure_sample_fairness(40, 3, 400)
      ArraySpecs.measure_sample_fairness(40, 4, 400)
      ArraySpecs.measure_sample_fairness(40, 8, 400)
      ArraySpecs.measure_sample_fairness(40, 16, 400)
      ArraySpecs.measure_sample_fairness_large_sample_size(100, 80, 4000)
    end
  end

  it "returns nil for an empty Array" do
    [].sample.should be_nil
  end

  it "returns nil for an empty array when called without n and a Random is given" do
    [].sample(random: Random.new(42)).should be_nil
  end

  it "returns a single value when not passed a count" do
    [4].sample.should equal(4)
  end

  it "returns a single value when not passed a count and a Random is given" do
    [4].sample(random: Random.new(42)).should equal(4)
  end

  it "returns a single value when not passed a count and a Random class is given" do
    [4].sample(random: Random).should equal(4)
  end

  it "returns an empty Array when passed zero" do
    [4].sample(0).should == []
  end

  it "returns an Array of elements when passed a count" do
    [1, 2, 3, 4].sample(3).should be_an_instance_of(Array)
  end

  it "returns elements from the Array" do
    array = [1, 2, 3, 4]
    array.sample(3).all? { |x| array.should include(x) }
  end

  it "returns at most the number of elements in the Array" do
    array = [1, 2, 3, 4]
    result = array.sample(20)
    result.size.should == 4
  end

  it "does not return the same value if the Array has unique values" do
    array = [1, 2, 3, 4]
    result = array.sample(20)
    result.sort.should == array
  end

  it "may return the same value if the array is not unique" do
    [4, 4].sample(2).should == [4,4]
  end

  it "calls #to_int to convert the count when passed an Object" do
    [1, 2, 3, 4].sample(mock_int(2)).size.should == 2
  end

  it "raises ArgumentError when passed a negative count" do
    -> { [1, 2].sample(-1) }.should raise_error(ArgumentError)
  end

  it "does not return subclass instances with Array subclass" do
    ArraySpecs::MyArray[1, 2, 3].sample(2).should be_an_instance_of(Array)
  end

  describe "with options" do
    it "calls #rand on the Object passed by the :random key in the arguments Hash" do
      obj = mock("array_sample_random")
      obj.should_receive(:rand).and_return(0.5)

      [1, 2].sample(random: obj).should be_an_instance_of(Integer)
    end

    it "raises a NoMethodError if an object passed for the RNG does not define #rand" do
      obj = BasicObject.new

      -> { [1, 2].sample(random: obj) }.should raise_error(NoMethodError)
    end

    describe "when the object returned by #rand is an Integer" do
      it "uses the integer as index" do
        random = mock("array_sample_random_ret")
        random.should_receive(:rand).and_return(0)

        [1, 2].sample(random: random).should == 1

        random = mock("array_sample_random_ret")
        random.should_receive(:rand).and_return(1)

        [1, 2].sample(random: random).should == 2
      end

      it "raises a RangeError if the value is less than zero" do
        random = mock("array_sample_random")
        random.should_receive(:rand).and_return(-1)

        -> { [1, 2].sample(random: random) }.should raise_error(RangeError)
      end

      it "raises a RangeError if the value is equal to the Array size" do
        random = mock("array_sample_random")
        random.should_receive(:rand).and_return(2)

        -> { [1, 2].sample(random: random) }.should raise_error(RangeError)
      end

      it "raises a RangeError if the value is greater than the Array size" do
        random = mock("array_sample_random")
        random.should_receive(:rand).and_return(3)

        -> { [1, 2].sample(random: random) }.should raise_error(RangeError)
      end
    end
  end

  describe "when the object returned by #rand is not an Integer but responds to #to_int" do
    it "calls #to_int on the Object" do
      value = mock("array_sample_random_value")
      value.should_receive(:to_int).and_return(1)
      random = mock("array_sample_random")
      random.should_receive(:rand).and_return(value)

      [1, 2].sample(random: random).should == 2
    end

    it "raises a RangeError if the value is less than zero" do
      value = mock("array_sample_random_value")
      value.should_receive(:to_int).and_return(-1)
      random = mock("array_sample_random")
      random.should_receive(:rand).and_return(value)

      -> { [1, 2].sample(random: random) }.should raise_error(RangeError)
    end

    it "raises a RangeError if the value is equal to the Array size" do
      value = mock("array_sample_random_value")
      value.should_receive(:to_int).and_return(2)
      random = mock("array_sample_random")
      random.should_receive(:rand).and_return(value)

      -> { [1, 2].sample(random: random) }.should raise_error(RangeError)
    end
  end
end
