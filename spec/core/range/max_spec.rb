require_relative '../../spec_helper'

describe "Range#max" do
  it "returns the maximum value in the range when called with no arguments" do
    (1..10).max.should == 10
    (1...10).max.should == 9
    (0...2**64).max.should == 18446744073709551615
    ('f'..'l').max.should == 'l'
    ('a'...'f').max.should == 'e'
  end

  it "returns the maximum value in the Float range when called with no arguments" do
    (303.20..908.1111).max.should == 908.1111
  end

  it "raises TypeError when called on an exclusive range and a non Integer value" do
    -> { (303.20...908.1111).max }.should raise_error(TypeError)
  end

  it "returns nil when the endpoint is less than the start point" do
    (100..10).max.should be_nil
    ('z'..'l').max.should be_nil
  end

  it "returns nil when the endpoint equals the start point and the range is exclusive" do
    (5...5).max.should be_nil
  end

  it "returns the endpoint when the endpoint equals the start point and the range is inclusive" do
    (5..5).max.should equal(5)
  end

  it "returns nil when the endpoint is less than the start point in a Float range" do
    (3003.20..908.1111).max.should be_nil
  end

  it "returns end point when the range is Time..Time(included end point)" do
    time_start = Time.now
    time_end = Time.now + 1.0
    (time_start..time_end).max.should equal(time_end)
  end

  it "raises TypeError when called on a Time...Time(excluded end point)" do
    time_start = Time.now
    time_end = Time.now + 1.0
    -> { (time_start...time_end).max  }.should raise_error(TypeError)
  end

  it "raises RangeError when called on an endless range" do
    -> { eval("(1..)").max }.should raise_error(RangeError)
  end

  it "returns the end point for beginless ranges" do
    (..1).max.should == 1
    (..1.0).max.should == 1.0
  end

  ruby_version_is ""..."3.5" do
    it "raises for an exclusive beginless Integer range" do
      -> {
        (...1).max
      }.should raise_error(TypeError, 'cannot exclude end value with non Integer begin value')
    end
  end

  ruby_version_is "3.5" do
    it "returns the end point for exclusive beginless Integer ranges" do
      (...1).max.should == 0
    end
  end

  it "raises for an exclusive beginless non Integer range" do
  NATFIXME 'Fix error message', exception: SpecFailedException, message: /but the message was/ do
      -> {
        (...1.0).max
      }.should raise_error(TypeError, 'cannot exclude non Integer end value')
    end
  end
end

describe "Range#max given a block" do
  it "passes each pair of values in the range to the block" do
    acc = []
    (1..10).max {|a,b| acc << [a,b]; a }
    acc.flatten!
    (1..10).each do |value|
      acc.include?(value).should be_true
    end
  end

  it "passes each pair of elements to the block in reversed order" do
    acc = []
    (1..5).max {|a,b| acc << [a,b]; a }
    acc.should == [[2,1],[3,2], [4,3], [5, 4]]
  end

  it "calls #> and #< on the return value of the block" do
    obj = mock('obj')
    obj.should_receive(:>).exactly(2).times
    obj.should_receive(:<).exactly(2).times
    (1..3).max {|a,b| obj }
  end

  it "returns the element the block determines to be the maximum" do
    (1..3).max {|a,b| -3 }.should == 1
  end

  it "returns nil when the endpoint is less than the start point" do
    (100..10).max {|x,y| x <=> y}.should be_nil
    ('z'..'l').max {|x,y| x <=> y}.should be_nil
    (5...5).max {|x,y| x <=> y}.should be_nil
  end

  it "raises RangeError when called with custom comparison method on an beginless range" do
    -> { (..1).max {|a, b| a} }.should raise_error(RangeError)
  end
end
