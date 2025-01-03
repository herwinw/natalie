require_relative '../../spec_helper'

describe "Complex#to_r" do
  describe "when the imaginary part is Integer 0" do
    it "returns the result of sending #to_r to the real part" do
      real = mock_numeric('real')
      real.should_receive(:to_r).and_return(:r)
      Complex(real, 0).to_r.should == :r
    end
  end

  describe "when the imaginary part is Rational 0" do
    it "returns the result of sending #to_r to the real part" do
      real = mock_numeric('real')
      real.should_receive(:to_r).and_return(:r)
      Complex(real, Rational(0)).to_r.should == :r
    end
  end

  describe "when the imaginary part responds to #== 0 with true" do
    it "returns the result of sending #to_r to the real part" do
      real = mock_numeric('real')
      real.should_receive(:to_r).and_return(:r)
      imag = mock_numeric('imag')
      imag.should_receive(:==).with(0).any_number_of_times.and_return(true)
      Complex(real, imag).to_r.should == :r
    end
  end

  describe "when the imaginary part is non-zero" do
    it "raises RangeError" do
      -> { Complex(0, 1).to_r }.should raise_error(RangeError)
    end
  end

  describe "when the imaginary part is Float 0.0" do
    ruby_version_is ''...'3.4' do
      it "raises RangeError" do
        -> { Complex(0, 0.0).to_r }.should raise_error(RangeError)
      end
    end

    ruby_version_is '3.4' do
      it "returns a Rational" do
        NATFIXME 'it returns a Rational', exception: RangeError, message: "can't convert 0+0.0i into Rational" do
          Complex(0, 0.0).to_r.should == 0r
        end
      end
    end
  end
end
