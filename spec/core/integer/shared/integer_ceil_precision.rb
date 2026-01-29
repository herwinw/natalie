describe :integer_ceil_precision, shared: true do
  context "precision is zero" do
    it "returns Integer equal to self" do
      NATFIXME 'Implement precision argument', condition: @method == :Rational, exception: ArgumentError, message: 'wrong number of arguments' do
        send(@method, 0).ceil(0).should.eql?(0)
        send(@method, 123).ceil(0).should.eql?(123)
        send(@method, -123).ceil(0).should.eql?(-123)
      end
    end
  end

  context "precision is positive" do
    it "returns self" do
      NATFIXME 'Implement precision argument', condition: @method == :Rational, exception: ArgumentError, message: 'wrong number of arguments' do
        send(@method, 0).ceil(1).should.eql?(send(@method, 0))
        send(@method, 0).ceil(10).should.eql?(send(@method, 0))

        send(@method, 123).ceil(10).should.eql?(send(@method, 123))
        send(@method, -123).ceil(10).should.eql?(send(@method, -123))
      end
    end
  end

  context "precision is negative" do
    it "always returns 0 when self is 0" do
      NATFIXME 'Implement precision argument', condition: @method == :Rational, exception: ArgumentError, message: 'wrong number of arguments' do
        send(@method, 0).ceil(-1).should.eql?(0)
        send(@method, 0).ceil(-10).should.eql?(0)
      end
    end

    it "returns Integer equal to self if there are already at least precision.abs trailing zeros" do
      NATFIXME 'Implement precision argument', condition: @method == :Rational, exception: ArgumentError, message: 'wrong number of arguments' do
        send(@method, 10).ceil(-1).should.eql?(10)
        send(@method, 100).ceil(-1).should.eql?(100)
        send(@method, 100).ceil(-2).should.eql?(100)
        send(@method, -10).ceil(-1).should.eql?(-10)
        send(@method, -100).ceil(-1).should.eql?(-100)
        send(@method, -100).ceil(-2).should.eql?(-100)
      end
    end

    it "returns smallest Integer greater than self with at least precision.abs trailing zeros" do
      NATFIXME 'Implement precision argument', condition: @method == :Rational, exception: ArgumentError, message: 'wrong number of arguments' do
        send(@method, 123).ceil(-1).should.eql?(130)
        send(@method, 123).ceil(-2).should.eql?(200)
        send(@method, 123).ceil(-3).should.eql?(1000)

        send(@method, -123).ceil(-1).should.eql?(-120)
        send(@method, -123).ceil(-2).should.eql?(-100)
        send(@method, -123).ceil(-3).should.eql?(0)

        send(@method, 100).ceil(-3).should.eql?(1000)
        send(@method, -100).ceil(-3).should.eql?(0)
      end
    end

    # Bug #20654
    it "returns 10**precision.abs when precision.abs has more digits than self" do
      NATFIXME 'Implement precision argument', condition: @method == :Rational, exception: ArgumentError, message: 'wrong number of arguments' do
        send(@method, 123).ceil(-20).should.eql?(100000000000000000000)
        send(@method, 123).ceil(-50).should.eql?(100000000000000000000000000000000000000000000000000)
      end
    end
  end
end
