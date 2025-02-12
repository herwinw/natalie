require_relative '../../spec_helper'

describe "Time#<=>" do
  it "returns 1 if the first argument is a point in time after the second argument" do
    (Time.now <=> Time.at(0)).should == 1
  end

  it "returns 1 if the first argument is a point in time after the second argument (down to a millisecond)" do
    (Time.at(0, 1000) <=> Time.at(0, 0)).should == 1
    (Time.at(1202778512, 1000) <=> Time.at(1202778512, 999)).should == 1
  end

  it "returns 1 if the first argument is a point in time after the second argument (down to a microsecond)" do
    (Time.at(0, 100) <=> Time.at(0, 0)).should == 1
    (Time.at(1202778512, 100) <=> Time.at(1202778512, 99)).should == 1
  end

  it "returns 0 if time is the same as other" do
    (Time.at(1202778513) <=> Time.at(1202778513)).should == 0
    (Time.at(100, 100) <=> Time.at(100, 100)).should == 0
  end

  it "returns -1 if the first argument is a point in time before the second argument" do
    (Time.at(0) <=> Time.now).should == -1
    (Time.at(100, 100) <=> Time.at(101, 100)).should == -1
  end

  it "returns -1 if the first argument is a point in time before the second argument (down to a millisecond)" do
    (Time.at(0, 0) <=> Time.at(0, 1000)).should == -1
  end

  it "returns -1 if the first argument is a point in time before the second argument (down to a microsecond)" do
    (Time.at(0, 0) <=> Time.at(0, 100)).should == -1
  end

  it "returns 1 if the first argument is a fraction of a microsecond after the second argument" do
    (Time.at(100, Rational(1,1000)) <=> Time.at(100, 0)).should == 1
  end

  it "returns 0 if time is the same as other, including fractional microseconds" do
    (Time.at(100, Rational(1,1000)) <=> Time.at(100, Rational(1,1000))).should == 0
  end

  it "returns -1 if the first argument is a fraction of a microsecond before the second argument" do
    (Time.at(100, 0) <=> Time.at(100, Rational(1,1000))).should == -1
  end

  it "returns nil when compared to an Integer because Time does not respond to #coerce" do
    time = Time.at(1)
    time.respond_to?(:coerce).should == false
    time.should_receive(:respond_to?).exactly(2).and_return(false)
    -> {
      (time <=> 2).should == nil
      (2 <=> time).should == nil
    }.should_not complain
  end

  context "given different timezones" do
    it "returns 0 if time is the same as other" do
      # three timezones, all at the same timestamp
      time_utc = Time.new(2000, 1, 1, 0, 0, 0, 0)
      time_cet = Time.new(2000, 1, 1, 1, 0, 0, '+01:00')
      time_brt = Time.new(1999, 12, 31, 21, 0, 0, '-03:00')
      NATFIXME 'Time#<=> should account for different timezones', exception: SpecFailedException do
        (time_utc <=> time_cet).should == 0
        (time_utc <=> time_brt).should == 0
        (time_cet <=> time_brt).should == 0
      end
    end

    it "returns -1 if the first argument is before the second argument" do
      # time_brt is later, even though the date is earlier
      time_utc = Time.new(2000, 1, 1, 0, 0, 0, 0)
      time_brt = Time.new(1999, 12, 31, 23, 0, 0, '-03:00')
      NATFIXME 'Time#<=> should account for different timezones', exception: SpecFailedException do
        (time_utc <=> time_brt).should == -1
      end
    end

    it "returns 1 if the first argument is before the second argument" do
      # time_brt is later, even though the date is earlier
      time_utc = Time.new(2000, 1, 1, 0, 0, 0, 0)
      time_brt = Time.new(1999, 12, 31, 23, 0, 0, '-03:00')
      NATFIXME 'Time#<=> should account for different timezones', exception: SpecFailedException do
        (time_brt <=> time_utc).should == 1
      end
    end
  end

  describe "given a non-Time argument" do
    it "returns nil if argument <=> self returns nil" do
      t = Time.now
      obj = mock('time')
      obj.should_receive(:<=>).with(t).and_return(nil)
      (t <=> obj).should == nil
    end

    it "returns -1 if argument <=> self is greater than 0" do
      t = Time.now
      r = mock('r')
      r.should_receive(:>).with(0).and_return(true)
      obj = mock('time')
      obj.should_receive(:<=>).with(t).and_return(r)
      (t <=> obj).should == -1
    end

    it "returns 1 if argument <=> self is not greater than 0 and is less than 0" do
      t = Time.now
      r = mock('r')
      r.should_receive(:>).with(0).and_return(false)
      r.should_receive(:<).with(0).and_return(true)
      obj = mock('time')
      obj.should_receive(:<=>).with(t).and_return(r)
      (t <=> obj).should == 1
    end

    it "returns 0 if argument <=> self is neither greater than 0 nor less than 0" do
      t = Time.now
      r = mock('r')
      r.should_receive(:>).with(0).and_return(false)
      r.should_receive(:<).with(0).and_return(false)
      obj = mock('time')
      obj.should_receive(:<=>).with(t).and_return(r)
      (t <=> obj).should == 0
    end

    it "returns nil if argument also uses an inverse comparison for <=>" do
      t = Time.now
      r = mock('r')
      def r.<=>(other); other <=> self; end
      r.should_receive(:<=>).once

      (t <=> r).should be_nil
    end
  end
end
