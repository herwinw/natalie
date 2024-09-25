require_relative '../../spec_helper'
require_relative 'fixtures/classes'

ruby_version_is "3.2" do
  describe "Data#to_h" do
    it "transforms the data object into a hash" do
      data = DataSpecs::Measure.new(amount: 42, unit: 'km')
      data.to_h.should == { amount: 42, unit: 'km' }
    end
  end
end
