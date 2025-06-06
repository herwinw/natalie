require_relative '../../spec_helper'

describe "FrozenError.new" do
  it "should take optional receiver argument" do
    o = Object.new
    FrozenError.new("msg", receiver: o).receiver.should equal(o)
  end
end

describe "FrozenError#receiver" do
  it "should return frozen object that modification was attempted on" do
    o = Object.new.freeze
    begin
      def o.x; end
    rescue => e
      e.should be_kind_of(FrozenError)
      NATFIXME "Singleton class method does not provide a receiver, instead returns the class itself which is incorrect.", exception: SpecFailedException do
        e.receiver.should equal(o)
      end
    else
      raise
    end
  end
end

describe "FrozenError#message" do
  it "includes a receiver" do
    object = Object.new
    object.freeze

    NATFIXME 'FrozenError#message includes a receiver', exception: SpecFailedException do
      -> {
        def object.x; end
      }.should raise_error(FrozenError, "can't modify frozen object: #{object}")
    end

    object = [].freeze
    -> { object << nil }.should raise_error(FrozenError, "can't modify frozen Array: []")
  end
end

describe "Modifying a frozen object" do
  context "#inspect is redefined and modifies the object" do
    # NATFIXME: This breaks execution
    xit "returns ... instead of String representation of object" do
      object = Object.new
      def object.inspect; @a = 1 end
      def object.modify; @a = 2 end

      object.freeze

      # CRuby's message contains multiple whitespaces before '...'.
      # So handle both multiple and single whitespace.
      -> { object.modify }.should raise_error(FrozenError, /can't modify frozen .*?: \s*.../)
    end
  end
end
